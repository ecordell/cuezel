package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/coreos/go-oidc"
	"golang.org/x/oauth2"
)

const (
	cookieName = "jwt"
	state      = "thisisactuallyaverysecurecsrftoken"
)

var provider *oidc.Provider
var verifier *oidc.IDTokenVerifier
var providerName = os.Getenv("PROVIDER")
var endpoint = oauth2.Endpoint{}
var clientID = ""
var clientSecret = ""

type (
	// https://openid.net/specs/openid-connect-registration-1_0.html#RegistrationRequest
	ClientRegistration struct {
		Name                    string   `json:"client_name"`
		ResponseTypes           []string `json:"response_types"`
		TokenEndpointAuthMethod string   `json:"token_endpoint_auth_method"`
		InitiateLoginURI        string   `json:"initiate_login_uri"`
		RedirectURIs            []string `json:"redirect_uris"`
		ApplicationType         string   `json:"application_type"`
		FrontchannelLogoutURI   string   `json:"frontchannel_logout_uri"`
	}

	// https://openid.net/specs/openid-connect-registration-1_0.html#RegistrationResponse
	// https://openid.net/specs/openid-connect-registration-1_0.html#RegistrationError
	ClientRegistrationResponse struct {
		Error            string `json:"error,omitempty"`
		ErrorDescription string `json:"error_description,omitempty"`

		Client
	}

	Client struct {
		Name                    string   `json:"client_name,omitempty"`
		ID                      string   `json:"client_id"`
		Secret                  string   `json:"client_secret,omitempty"`
		RedirectURIs            []string `json:"redirect_uris,omitempty"`
		ResponseTypes           []string `json:"response_types,omitempty"`
		TokenEndpointAuthMethod string   `json:"token_endpoint_auth_method,omitempty"`
		InitiateLoginURI        string   `json:"initiate_login_uri,omitempty"`
		ApplicationType         string   `json:"application_type,omitempty"`
		FrontchannelLogoutURI   string   `json:"frontchannel_logout_uri,omitempty"`
		IssuedAt                jsonTime `json:"client_id_issued_at,omitempty"`
		SecretExpiresAt         jsonTime `json:"client_secret_expires_at"`
	}
)

type jsonTime time.Time

func (j *jsonTime) UnmarshalJSON(b []byte) error {
	var n json.Number
	if err := json.Unmarshal(b, &n); err != nil {
		return err
	}
	var unix int64

	if t, err := n.Int64(); err == nil {
		unix = t
	} else {
		f, err := n.Float64()
		if err != nil {
			return err
		}
		unix = int64(f)
	}
	*j = jsonTime(time.Unix(unix, 0))
	return nil
}

func (j jsonTime) MarshalJSON() ([]byte, error) {
	return json.Marshal(json.Number(strconv.FormatInt(time.Time(j).Unix(), 10)))
}

func main() {
	var err error
	provider, err = oidc.NewProvider(context.Background(), providerName)
	if err != nil {
		// ignore error because provider doesn't match issuer
		log.Fatal(err)
	}

	reg := ClientRegistration{
		Name: os.Getenv("POD_NAME"),
		RedirectURIs: []string{os.Getenv("REDIRECT_URI")},
		TokenEndpointAuthMethod: "client_secret_post",
		// TODO: is this needed if it's already configured in hydra?
		InitiateLoginURI: os.Getenv("LOGIN_URL"),
	}
	regBytes, err := json.Marshal(reg)
	if err != nil {
		log.Fatal(err)
	}

	req, err := http.NewRequest("POST", os.Getenv("REGISTRATION_URI"), bytes.NewBuffer(regBytes))
	if err != nil {
		log.Fatal(err)
	}
	req.Header = map[string][]string{"Content-Type": {"application/json"}, "Accept": {"application/json"}}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Fatal(err)
	}
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Fatal(err)
	}

	var regResp ClientRegistrationResponse
	if err := json.Unmarshal(body, &regResp); err != nil {
		log.Fatal(err)
	}

	clientID = regResp.ID
	clientSecret = regResp.Secret

	fmt.Println(regResp.RedirectURIs)

	verifier = provider.Verifier(
		&oidc.Config{ClientID: clientID, SupportedSigningAlgs: []string{"RS256"}},
	)

	if len(clientID) == 0 || len(clientSecret) == 0 {
		log.Fatal("registration failed")
	}

	endpoint = provider.Endpoint()
	// should match token_endpoint_auth_method
	endpoint.AuthStyle = oauth2.AuthStyleInParams

	http.HandleFunc("/auth/verify", verifyHandler)
	http.HandleFunc("/auth/signin", signinHandler)
	http.HandleFunc("/auth/callback", callbackHandler)
	log.Fatal(http.ListenAndServe(":8000", nil))
}

func verifyHandler(w http.ResponseWriter, r *http.Request) {
	token, err := r.Cookie(cookieName)
	if err != nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	if token == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	_, err = verifier.Verify(context.Background(), token.Value)
	if err != nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	w.WriteHeader(http.StatusNoContent)
	return
}

func signinHandler(w http.ResponseWriter, r *http.Request) {
	token, err := r.Cookie(cookieName)
	if token != nil {
		_, err = verifier.Verify(context.Background(), token.Value)
		if err == nil {
			if r.URL.Query().Get("rd") != "" {
				http.Redirect(w, r, r.URL.Query().Get("rd"), http.StatusFound)
				return
			}
			w.WriteHeader(http.StatusOK)
			return
		}
	}
	config := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:     endpoint,
		RedirectURL:  redirectURL(),
		Scopes:       []string{"openid"},
	}
	http.Redirect(w, r, config.AuthCodeURL(state), http.StatusFound)
	return
}

func callbackHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Query().Get("state") != state {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "Invalid state")
	}

	config := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Endpoint:     endpoint,
		RedirectURL:  redirectURL(),
		Scopes:       []string{"openid"},
	}

	oauth2Token, err := config.Exchange(context.Background(), r.URL.Query().Get("code"))
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, "Failed to exchange token: %s", err.Error())
		return
	}

	rawIDToken, ok := oauth2Token.Extra("id_token").(string)
	if !ok {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "No id_token field in oauth2 token.")
		return
	}
	_, err = verifier.Verify(context.Background(), rawIDToken)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "Failed to verify ID Token: %s", err.Error())
	}

	cookie := http.Cookie{
		Name:  cookieName,
		Path:  "/",
		Value: rawIDToken,
	}
	http.SetCookie(w, &cookie)
	if r.URL.Query().Get("rd") != "" {
		http.Redirect(w, r, r.URL.Query().Get("rd"), http.StatusFound)
		return
	}
	http.Redirect(w, r, "/", http.StatusFound)
	return
}

func redirectURL() string {
	return os.Getenv("REDIRECT_URI")
}
