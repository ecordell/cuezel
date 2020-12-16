package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"

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
var clientID = os.Getenv("CLIENT_ID")
var clientSecret = os.Getenv("CLIENT_SECRET")

func main() {
	var err error
	provider, err = oidc.NewProvider(context.Background(), providerName)
	if err != nil {
		log.Fatal(err)
	}
	verifier = provider.Verifier(
		&oidc.Config{ClientID: clientID, SupportedSigningAlgs: []string{"RS256"}},
	)
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
		Endpoint:     provider.Endpoint(),
		RedirectURL:  redirectURL(r),
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
		Endpoint:     provider.Endpoint(),
		RedirectURL:  redirectURL(r),
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

func redirectURL(r *http.Request) string {
	host := r.Host
	if h := r.Header.Get("X-Original-Url"); h != "" {
		u, err := url.Parse(h)
		if err == nil {
			host = u.Hostname()
		}
	}
	rd := r.URL.Query().Get("rd")
	if rd != "" {
		rd = "?rd=" + rd
	}
	return fmt.Sprintf("http://%v/auth/callback%v", host, rd)
}
