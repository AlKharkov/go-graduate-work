package main

import (
	"fmt"
	"os"
)

func main() {
	filename := "../../testdata/0.go"
	if len(os.Args) > 1 {
		filename = os.Args[1]
	}

	// Создаем папку output если её нет
	outputDir := "../../output"
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		fmt.Println("Error creating output directory:", err)
		os.Exit(1)
	}

	if err := ConvertFile(filename, outputDir); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
}
