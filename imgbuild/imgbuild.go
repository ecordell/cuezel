package imgbuild

import (
	"context"
	"github.com/containers/image/v5/signature"
	"github.com/opencontainers/umoci/mutate"
	"github.com/opencontainers/umoci/oci/layer"
	"github.com/pkg/errors"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/load"
	"github.com/containers/common/pkg/retry"
	imgcopy "github.com/containers/image/v5/copy"
	"github.com/containers/image/v5/transports/alltransports"
	"github.com/containers/image/v5/types"
	ispec "github.com/opencontainers/image-spec/specs-go/v1"
	"github.com/opencontainers/umoci"
	"github.com/opencontainers/umoci/oci/cas/dir"
	"github.com/opencontainers/umoci/oci/casext"

	"fmt"
	"io"
)

type ImgRef struct {
	Ref  string `json:"ref"`
	Arch string `json:"arch"`
	OS   string `json:"os"`
}

type ImgBuild struct {
	BinPath     string `json:"binPath"`
	Base        ImgRef `json:"base"`
	Ports       []int  `json:"ports"`
	Name        string `json:"name"`
	Cmd         string `json:"cmd"`
	ArchiveName string `json:"archive"`
}

func Build(ctx context.Context, out io.Writer, r cue.Runtime, instance *cue.Instance) ([]ImgBuild, *cue.Instance, error) {
	// load schema for image definitions
	sis := load.Instances([]string{"."}, &load.Config{
		Dir: "./manifests/imgbuild",
	})
	if len(sis) > 1 {
		return nil, instance, fmt.Errorf("multiple instance loading currently not supported")
	}
	if len(sis) < 1 {
		return nil, instance, fmt.Errorf("no instances found")
	}
	si, err := r.Build(sis[0])
	if err != nil {
		return nil, instance, err
	}
	binImageSchema := si.Value().LookupDef("GoBinImage")

	// find all image definitions
	imageDefs := make([]cue.Value, 0)
	itr, err := instance.Value().Fields(cue.Definitions(true))
	if err != nil {
		return nil, instance, err
	}
	for itr.Next() {
		val := itr.Value()
		if err := val.Unify(binImageSchema).Validate(); err == nil {
			imageDefs = append(imageDefs, val)
		} else {
			// TODO: debug logs
			//fmt.Println(itr.Label(), err)
		}
	}

	builtImages := make([]ImgBuild, 0)
	for _, img := range imageDefs {
		var imgspec ImgBuild

		if err := img.Decode(&imgspec); err != nil {
			return nil, instance, err
		}
		fmt.Println(imgspec)

		exposedPorts := map[string]struct{}{}
		for _, p := range imgspec.Ports {
			exposedPorts[strconv.Itoa(p)] = struct{}{}
		}
		_, binName := filepath.Split(imgspec.BinPath)

		// pull base images to a shared cache dir
		srcRef, err := alltransports.ParseImageName(imgspec.Base.Ref)
		if err != nil {
			return nil, instance, fmt.Errorf("Invalid source name %s: %v", imgspec.Base.Ref, err)
		}
		destRef, err := alltransports.ParseImageName("oci:local:test")
		if err != nil {
			return nil, instance, fmt.Errorf("Invalid destination name %s: %v", "oci:local:test", err)
		}

		if imgspec.Name == "" {
			imgspec.Name = GenerateName("gen:img-")
		}

		policyCtx, err := signature.NewPolicyContext(&signature.Policy{Default: []signature.PolicyRequirement{signature.NewPRInsecureAcceptAnything()}})
		if err != nil {
			return nil, instance, err
		}
		err = retry.RetryIfNecessary(ctx, func() error {
			_, err = imgcopy.Image(ctx, policyCtx, destRef, srcRef, &imgcopy.Options{
				ReportWriter: out,
				SourceCtx: &types.SystemContext{
					ArchitectureChoice: imgspec.Base.Arch,
					OSChoice:           imgspec.Base.OS,
				},
				DestinationCtx: &types.SystemContext{},
			})
			return err
		}, &retry.RetryOptions{
			MaxRetry: 5,
			Delay:    time.Second,
		})
		if err != nil {
			return nil, instance, err
		}

		// unpack
		engine, err := dir.Open("./local")
		if err != nil {
			return nil, instance, errors.Wrap(err, "open CAS")
		}
		engineExt := casext.NewEngine(engine)

		descriptorPaths, err := engineExt.ResolveReference(context.Background(), "test")
		if err != nil {
			return nil, instance, errors.Wrap(err, "get descriptor")
		}
		if len(descriptorPaths) == 0 {
			return nil, instance, errors.Errorf("tag not found: %s", "test")
		}
		if len(descriptorPaths) != 1 {
			return nil, instance, errors.Errorf("tag is ambiguous: %s", "test")
		}

		// Create the mutator.
		mutator, err := mutate.New(engine, descriptorPaths[0])
		if err != nil {
			return nil, instance, errors.Wrap(err, "create mutator for base image")
		}

		var meta umoci.Meta
		meta.Version = umoci.MetaVersion
		meta.MapOptions = layer.MapOptions{
			Rootless: true,
		}
		reader := layer.GenerateInsertLayer(imgspec.BinPath, filepath.Join("bin", binName), false, &meta.MapOptions)
		defer reader.Close()

		var history *ispec.History
		created := time.Now()
		history = &ispec.History{
			Comment:    "",
			Created:    &created,
			CreatedBy:  "cue imgbuild",
			EmptyLayer: false,
		}

		if err := mutator.Add(ctx, reader, history); err != nil {
			return nil, instance, errors.Wrap(err, "add diff layer")
		}

		imageConfig, err := mutator.Config(ctx)
		if err != nil {
			return nil, instance, errors.Wrap(err, "get base config")
		}

		imageMeta, err := mutator.Meta(ctx)
		if err != nil {
			return nil, instance, errors.Wrap(err, "get base metadata")
		}
		annotations, err := mutator.Annotations(ctx)
		if err != nil {
			return nil, instance, errors.Wrap(err, "get base annotations")
		}
		imageConfig.ExposedPorts = exposedPorts

		// TODO: set command

		if err := mutator.Set(ctx, imageConfig, imageMeta, annotations, history); err != nil {
			return nil, instance, errors.Wrap(err, "set modified configuration")
		}

		newDescriptorPath, err := mutator.Commit(ctx)
		if err != nil {
			return nil, instance, errors.Wrap(err, "commit mutated image")
		}

		fmt.Fprintf(out, "new image manifest created: %s->%s\n", newDescriptorPath.Root().Digest, newDescriptorPath.Descriptor().Digest)

		if err := engineExt.UpdateReference(ctx, imgspec.Name, newDescriptorPath.Root()); err != nil {
			return nil, instance, errors.Wrap(err, "add new tag")
		}
		fmt.Fprintf(out, "updated tag for image manifest: %s\n", imgspec.Name)

		if err := engine.Close(); err != nil {
			return nil, instance, err
		}

		outRef, err := alltransports.ParseImageName("oci:local:" + imgspec.Name)
		if err != nil {
			return nil, instance, fmt.Errorf("invalid final image name %s: %v", imgspec.Name, err)
		}

		if imgspec.ArchiveName != "" {
			if err := os.Remove(imgspec.ArchiveName); err != nil {
				return nil, instance, fmt.Errorf("couldn't clear existing archive %s: %b", imgspec.ArchiveName, err)
			}
			tarRef, err := alltransports.ParseImageName("docker-archive:" + imgspec.ArchiveName)
			if err != nil {
				return nil, instance, fmt.Errorf("invalid tar name %s: %v", "docker-archive:" + imgspec.ArchiveName, err)
			}
			_, err = imgcopy.Image(ctx, policyCtx, tarRef, outRef, &imgcopy.Options{
				ReportWriter: out,
				SourceCtx: &types.SystemContext{
					ArchitectureChoice: imgspec.Base.Arch,
					OSChoice:           imgspec.Base.OS,
				},
				DestinationCtx: &types.SystemContext{},
			})
			if err != nil {
				return nil, instance, err
			}
		}

		fmt.Println("Filling instance", img.Path().String())
		instance, err = instance.Fill(&imgspec, img.Path().String())
		if err != nil {
			return nil, instance, err
		}
		builtImages = append(builtImages, imgspec)
	}

	return builtImages, instance, nil
}

// stolen from apimachinery

const (
	maxNameLength          = 63
	randomLength           = 5
	maxGeneratedNameLength = maxNameLength - randomLength

	// We omit vowels from the set of available characters to reduce the chances
	// of "bad words" being formed.
	alphanums = "bcdfghjklmnpqrstvwxz2456789"
	// No. of bits required to index into alphanums string.
	alphanumsIdxBits = 5
	// Mask used to extract last alphanumsIdxBits of an int.
	alphanumsIdxMask = 1<<alphanumsIdxBits - 1
	// No. of random letters we can extract from a single int63.
	maxAlphanumsPerInt = 63 / alphanumsIdxBits
)

func GenerateName(base string) string {
	if len(base) > maxGeneratedNameLength {
		base = base[:maxGeneratedNameLength]
	}
	return fmt.Sprintf("%s%s", base, String(randomLength))
}

var rng = struct {
	sync.Mutex
	rand *rand.Rand
}{
	rand: rand.New(rand.NewSource(time.Now().UnixNano())),
}

// String generates a random alphanumeric string, without vowels, which is n
// characters long.  This will panic if n is less than zero.
// How the random string is created:
// - we generate random int63's
// - from each int63, we are extracting multiple random letters by bit-shifting and masking
// - if some index is out of range of alphanums we neglect it (unlikely to happen multiple times in a row)
func String(n int) string {
	b := make([]byte, n)
	rng.Lock()
	defer rng.Unlock()

	randomInt63 := rng.rand.Int63()
	remaining := maxAlphanumsPerInt
	for i := 0; i < n; {
		if remaining == 0 {
			randomInt63, remaining = rng.rand.Int63(), maxAlphanumsPerInt
		}
		if idx := int(randomInt63 & alphanumsIdxMask); idx < len(alphanums) {
			b[i] = alphanums[idx]
			i++
		}
		randomInt63 >>= alphanumsIdxBits
		remaining--
	}
	return string(b)
}
