package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	testDir := "testdata"
	outputDir := "output"

	if len(os.Args) > 1 && os.Args[1] == "-all" {
		// Массовая конвертация
		if err := ConvertAll(testDir, outputDir); err != nil {
			fmt.Println("Error:", err)
			os.Exit(1)
		}
		return
	}

	// Одиночная конвертация
	filename := "0.go"
	if len(os.Args) > 1 {
		filename = os.Args[1]
	}
	testFile := filepath.Join(testDir, filename)

	if err := os.MkdirAll(outputDir, 0755); err != nil {
		fmt.Println("Error creating output directory:", err)
		os.Exit(1)
	}

	if err := ConvertFile(testFile, outputDir); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
}

// ConvertAll конвертирует все .go файлы из srcDir в outputDir/out_all/<name>/.
func ConvertAll(srcDir, outputDir string) error {
	entries, err := os.ReadDir(srcDir)
	if err != nil {
		return fmt.Errorf("cannot read %s: %w", srcDir, err)
	}

	outAllDir := filepath.Join(outputDir, "out_all")
	if err := os.MkdirAll(outAllDir, 0755); err != nil {
		return fmt.Errorf("cannot create %s: %w", outAllDir, err)
	}

	var total, ok, failed int
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(name, ".go") {
			continue
		}
		total++

		// Имя подпапки — имя файла без .go
		base := strings.TrimSuffix(name, ".go")
		subDir := filepath.Join(outAllDir, base)
		if err := os.MkdirAll(subDir, 0755); err != nil {
			fmt.Printf("  ⚠️  cannot create %s: %v\n", subDir, err)
			failed++
			continue
		}

		srcFile := filepath.Join(srcDir, name)
		fmt.Printf("\n=== [%d] %s ===\n", total, name)
		if err := ConvertFile(srcFile, subDir); err != nil {
			fmt.Printf("  ❌ %s: %v\n", name, err)
			failed++
			continue
		}
		ok++
	}

	fmt.Printf("\n📊 Итого: %d файлов, успешно: %d, ошибок: %d\n", total, ok, failed)
	return nil
}
