// Copyright (c) 2018 Ryan Parman <https://ryanparman.com>
// Copyright (c) 2018 Contributors <https://github.com/skyzyx/terraform-registry.alfredworkflow/graphs/contributors>
//
// https://www.alfredapp.com/help/workflows/inputs/script-filter/json/

package main

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"time"

	// "github.com/davecgh/go-spew/spew"
	"github.com/parnurzeal/gorequest"
)

var (
	doc         InputDocument
	querystring string
)

type InputDocument struct {
	Meta    InputMeta     `json:"meta"`
	Modules []InputModule `json:"modules"`
}

type InputMeta struct {
	CurrentOffset int64 `json:"current_offset"`
	Limit         int64 `json:"limit"`
}

type InputModule struct {
	Description string    `json:"description"`
	Downloads   int64     `json:"downloads"`
	Id          string    `json:"id"`
	Name        string    `json:"name"`
	Namespace   string    `json:"namespace"`
	Owner       string    `json:"owner"`
	Provider    string    `json:"provider"`
	PublishedAt time.Time `json:"published_at"`
	Source      string    `json:"source"`
	Verified    bool      `json:"verified"`
	Version     string    `json:"version"`
}

type AlfredDocument struct {
	Items []AlfredItem `json:"items,omitempty"`
}

type AlfredItem struct {
	// Simple objects
	Arg          string `json:"arg,omitempty"`
	Autocomplete string `json:"autocomplete,omitempty"`
	Match        string `json:"match,omitempty"`
	QuicklookUrl string `json:"quicklookurl,omitempty"`
	Subtitle     string `json:"subtitle,omitempty"`
	Title        string `json:"title,omitempty"`
	Type         string `json:"type,omitempty"`
	UID          string `json:"uid,omitempty"`
	Valid        bool   `json:"valid,omitempty"`

	// Complex objects
	Icon AlfredIcon `json:"icon,omitempty"`
	// Mods AlfredModifierKeys `json:"mods,omitempty"`
	Text AlfredText `json:"text,omitempty"`
}

type AlfredIcon struct {
	Path string `json:"path,omitempty"`
	Type string `json:"type,omitempty"`
}

type AlfredText struct {
	Copy      string `json:"copy,omitempty"`
	LargeType string `json:"largetype,omitempty"`
}

// type AlfredModifierKeys struct {
// 	Alt     AlfredModifierKey `json:"alt,omitempty"`
// 	Command AlfredModifierKey `json:"cmd,omitempty"`
// }

// type AlfredModifierKey struct {
// 	Arg      string `json:"arg,omitempty"`
// 	Subtitle string `json:"subtitle,omitempty"`
// 	Valid    bool   `json:"valid,omitempty"`
// }

// The core function
func main() {
	alfred := new(AlfredDocument)
	querystring = url.QueryEscape(os.Args[1])

	_, body, _ := gorequest.New().Get("https://registry.terraform.io/v1/modules/search?limit=15&offset=0&q=" + querystring).End()
	err := json.Unmarshal([]byte(body), &doc)

	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	// spew.Dump(doc)

	// No results
	if len(doc.Modules) == 0 {
		alfred.Items = append(alfred.Items, AlfredItem{
			Title: "No results found.",
			Valid: false,
			Type: "default",
			Icon: AlfredIcon{
				Path: "images/terraform.png",
			},
		})
	}

	// Results
	for _, module := range doc.Modules {
		alfred.Items = append(alfred.Items, AlfredItem{
			UID: module.Id,
			Title: fmt.Sprintf(
				"%s%s/%s",
				map[bool]string{true: "👍🏼 ", false: ""}[module.Verified],
				module.Namespace,
				module.Name,
			),
			Subtitle:     module.Description,
			Arg:          module.Source,
			QuicklookUrl: module.Source,
			Valid:        true,
			Type:         "default",
			// Autocomplete string `json:"autocomplete,omitempty"`
			// Match        string `json:"match,omitempty"`
			Icon: AlfredIcon{
				// Type: "fileicon",
				Path: fmt.Sprintf("images/%s.png", determineIcon(module.Provider)),
			},
			Text: AlfredText{
				Copy:      module.Source,
				LargeType: module.Source,
			},
		})
	}

	// output, err := json.Marshal(alfred)
	output, err := json.MarshalIndent(alfred, "", "    ")

	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	fmt.Println(string(output))
}

func determineIcon(provider string) string {
	switch provider {
	case "alibaba", "aws", "azurerm", "digitalocean", "github", "google", "hashicorp", "kubernetes", "opc", "terraform":
		return provider
	default:
		return "generic"
	}
}
