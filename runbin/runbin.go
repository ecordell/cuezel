package runbin

import (
	"context"
	"cuelang.org/go/cue"
	"cuelang.org/go/cue/load"
	"fmt"
	"io"
	"os/exec"
)

type RunBin struct {
	Cmd           string   `json:"cmd"`
	Args          []string `json:"args"`
	Outfile       string   `json:"outfile"`
}

func Run(ctx context.Context, out io.Writer, r cue.Runtime, instance *cue.Instance) (*cue.Instance, error) {
	// load schema for image definitions
	sis := load.Instances([]string{"."}, &load.Config{
		Dir: "./manifests/runbin",
	})
	if len(sis) > 1 {
		return instance, fmt.Errorf("multiple instance loading currently not supported")
	}
	if len(sis) < 1 {
		return instance, fmt.Errorf("no instances found")
	}
	si, err := r.Build(sis[0])
	if err != nil {
		return instance, err
	}
	runSchema := si.Value().LookupDef("RunBin")

	// find all run defs
	runDefs := make([]cue.Value, 0)
	itr, err := instance.Value().Fields(cue.Definitions(true))
	if err != nil {
		return instance, err
	}
	for itr.Next() {
		val := itr.Value()
		if err := val.Unify(runSchema).Validate(); err == nil {
			fmt.Fprintf(out, "found run definition: %s\n", val.Path())
			runDefs = append(runDefs, val)
		} else {
			// TODO: debug logs
			//fmt.Println(itr.Label(), err)
		}
	}

	for _, def := range runDefs {
		var runSpec RunBin

		if err := def.Decode(&runSpec); err != nil {
			return instance, err
		}

		cmd := exec.CommandContext(ctx, runSpec.Cmd, runSpec.Args...)
		stdoutStderr, err := cmd.CombinedOutput()
		fmt.Fprint(out, string(stdoutStderr))
		if err != nil {
			return instance, err
		}

		fmt.Println("Filling instance", def.Path().String())
		instance, err = instance.Fill(&runSpec, def.Path().String())
		if err != nil {
			return instance, err
		}
	}

	return instance, nil
}
