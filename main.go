// Copyright (c) 2018-2022 Ryan Parman <https://ryanparman.com>
//
// https://www.alfredapp.com/help/workflows/inputs/script-filter/json/

package main

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"
	"time"

	// "github.com/davecgh/go-spew/spew".
	"github.com/parnurzeal/gorequest"
)

var (
	doc         inputDocument
	querystring string
)

const (
	minArgs = 2
)

type inputDocument struct {
	Meta    inputMeta     `json:"meta"`
	Modules []inputModule `json:"modules"`
}

type inputMeta struct {
	CurrentOffset int64 `json:"current_offset"`
	Limit         int64 `json:"limit"`
}

type inputModule struct {
	Description string    `json:"description"`
	Downloads   int64     `json:"downloads"`
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Namespace   string    `json:"namespace"`
	Owner       string    `json:"owner"`
	Provider    string    `json:"provider"`
	PublishedAt time.Time `json:"published_at"`
	Source      string    `json:"source"`
	Verified    bool      `json:"verified"`
	Version     string    `json:"version"`
}

type alfredDocument struct {
	Items []alfredItem `json:"items,omitempty"`
}

type alfredItem struct {
	// Simple objects
	Arg          string `json:"arg,omitempty"`
	Autocomplete string `json:"autocomplete,omitempty"`
	Match        string `json:"match,omitempty"`
	QuicklookURL string `json:"quicklookurl,omitempty"`
	Subtitle     string `json:"subtitle,omitempty"`
	Title        string `json:"title,omitempty"`
	Type         string `json:"type,omitempty"`
	UID          string `json:"uid,omitempty"`
	Valid        bool   `json:"valid,omitempty"`

	// Complex objects
	Icon alfredIcon         `json:"icon,omitempty"`
	Mods alfredModifierKeys `json:"mods,omitempty"`
	Text alfredText         `json:"text,omitempty"`
}

type alfredIcon struct {
	Path string `json:"path,omitempty"`
	Type string `json:"type,omitempty"`
}

type alfredText struct {
	Copy      string `json:"copy,omitempty"`
	LargeType string `json:"largetype,omitempty"`
}

type alfredModifierKeys struct {
	Alt     alfredModifierKey `json:"alt,omitempty"`
	Command alfredModifierKey `json:"cmd,omitempty"`
}

type alfredModifierKey struct {
	Arg          string `json:"arg,omitempty"`
	Subtitle     string `json:"subtitle,omitempty"`
	QuicklookURL string `json:"quicklookurl,omitempty"`
	Valid        bool   `json:"valid,omitempty"`
}

// The core function.
func main() {
	alfred := new(alfredDocument)

	if len(os.Args) < minArgs {
		fmt.Fprintf(os.Stderr, "A string to search for is required.")
		os.Exit(1)
	}

	querystring = url.QueryEscape(
		strings.Join(os.Args[1:], " "),
	)

	_, body, _ := gorequest.New().Get(
		fmt.Sprintf("https://registry.terraform.io/v1/modules/search?limit=15&offset=0&q=%s", querystring),
	).End()

	err := json.Unmarshal([]byte(body), &doc)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %s", err)
		os.Exit(1)
	}

	// No results
	if len(doc.Modules) == 0 {
		alfred.Items = append(alfred.Items, alfredItem{
			Title: "No results found.",
			Valid: false,
			Type:  "default",
			Icon: alfredIcon{
				Path: "images/terraform.png",
			},
		})
	}

	// Results
	for i := range doc.Modules {
		module := &doc.Modules[i]

		regURL := fmt.Sprintf("https://registry.terraform.io/modules/%s", module.ID)

		alfred.Items = append(alfred.Items, alfredItem{
			UID: module.ID,
			Title: fmt.Sprintf(
				"%s%s/%s",
				map[bool]string{true: "⭐️ ", false: ""}[module.Verified],
				module.Namespace,
				module.Name,
			),
			Subtitle:     module.Description,
			Arg:          regURL,
			QuicklookURL: regURL,
			Valid:        true,
			Type:         "default",
			// Autocomplete string `json:"autocomplete,omitempty"`
			// Match        string `json:"match,omitempty"`
			Icon: alfredIcon{
				// Type: "fileicon",
				Path: fmt.Sprintf("images/%s.png", determineIcon(module.Provider)),
			},
			Text: alfredText{
				Copy:      module.Source,
				LargeType: module.Source,
			},
			Mods: alfredModifierKeys{
				Alt: alfredModifierKey{
					Arg:          module.Source,
					Subtitle:     fmt.Sprintf("Open %s in your default browser.", module.Source),
					QuicklookURL: module.Source,
					Valid:        true,
				},
			},
		})
	}

	output, err := json.MarshalIndent(alfred, "", "    ")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	fmt.Println(string(output))
}

func determineIcon(provider string) string {
	switch provider {
	case "alibaba", "aws", "azurerm", "digitalocean", "github", "google",
		"hashicorp", "kubernetes", "opc", "terraform":
		return provider
	default:
		return "generic"
	}
}
