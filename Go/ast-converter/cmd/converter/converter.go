package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

// Translator преобразует Go код в ABML модель
type Translator struct {
	output     strings.Builder
	indent     int
	unknownLog strings.Builder
}

func (t *Translator) write(format string, args ...interface{}) {
	t.output.WriteString(strings.Repeat("  ", t.indent))
	t.output.WriteString(fmt.Sprintf(format, args...))
	t.output.WriteString("\n")
}

func (t *Translator) logUnknown(format string, args ...interface{}) {
	t.unknownLog.WriteString(fmt.Sprintf(format, args...))
	t.unknownLog.WriteString("\n")
}

// visitNode - единый метод для обработки узла: строит AST и конвертирует в ABML
func (t *Translator) visitNode(node ast.Node) {
	switch n := node.(type) {
	case *ast.File:
		t.write("(mo \"file\"")
		t.indent++
		t.write(":av \"package\" \"%s\"", n.Name.Name)
		t.write(":av \"block\" (mo \"block\"")
		t.indent++
		t.write(":av \"statements\" (list")
		t.indent++
		for _, decl := range n.Decls {
			t.visitNode(decl)
		}
		t.indent--
		t.write(")")
		t.indent--
		t.write(")")
		t.indent--
		t.write(")")

	case *ast.GenDecl:
		if n.Tok.String() != "import" {
			for _, spec := range n.Specs {
				t.visitNode(spec)
			}
		}

	case *ast.FuncDecl:
		t.write("(mo \"function decl\"")
		t.indent++
		t.write(":av \"name\" \"%s\"", n.Name.Name)
		t.write(":av \"value\" (mo \"function lit\"")
		t.indent++

		// Сигнатура
		t.write(":av \"signature\" (mo \"function signature\"")
		t.indent++
		if n.Type.Params != nil && len(n.Type.Params.List) > 0 {
			t.write(":av \"parameters\" (list")
			t.indent++
			t.visitNode(n.Type.Params)
			t.indent--
			t.write(")")
		}
		t.indent--
		t.write(")")

		// Тело
		if n.Body != nil {
			t.write(":av \"body\" (mo \"block\"")
			t.indent++
			t.write(":av \"statements\" (list")
			t.indent++
			for _, stmt := range n.Body.List {
				t.visitNode(stmt)
			}
			t.indent--
			t.write(")")
			t.indent--
			t.write(")")
		} else {
			t.write(":av \"body\" (mo \"block\" :av \"statements\" nil)")
		}

		t.indent--
		t.write(")")
		t.indent--
		t.write(")")

	case *ast.FieldList:
		for _, field := range n.List {
			t.visitNode(field)
		}

	case *ast.Field:
		for _, name := range n.Names {
			t.write("(mo \"param decl\" :av \"name\" \"%s\" :av \"type\" %s)", name.Name, t.getTypeString(n.Type))
		}

	case *ast.ValueSpec:
		names := make([]string, len(n.Names))
		for i, name := range n.Names {
			names[i] = name.Name
		}

		t.write("(mo \"var decl\"")
		t.indent++
		t.write(":av \"names\" (list %s)", t.formatNames(names))

		if n.Type != nil {
			t.visitNode(n.Type)
			t.write(":av \"types\" (list %s)", t.getTypeString(n.Type))
		} else {
			t.write(":av \"types\" (list \"UNKNOWN_TYPE\")")
		}

		if len(n.Values) > 0 {
			for _, val := range n.Values {
				t.visitNode(val)
			}
			t.write(":av \"values\" (list %s)", t.formatExpressions(n.Values))
		}
		t.indent--
		t.write(")")

	case *ast.Ident:
		// Обрабатываем как переменную, если это не тип
		if !t.isTypeIdentifier(n.Name) {
			t.write("(mo \"variable ref\" :av \"name\" \"%s\" :av \"type\" \"type\")", n.Name)
		}

	case *ast.SelectorExpr:
		t.visitNode(n.X)

	case *ast.CallExpr:
		// Обрабатываем вызов функции
		t.write("(mo \"function call\"")
		t.indent++
		t.write(":av \"function\" (mo \"selector expr\"")
		t.indent++

		switch fun := n.Fun.(type) {
		case *ast.SelectorExpr:
			if sel, ok := fun.X.(*ast.Ident); ok {
				t.write(":av \"receiver\" (mo \"variable ref\" :av \"name\" \"%s\" :av \"type\" \"type\")", sel.Name)
				t.write(":av \"name\" \"%s\"", fun.Sel.Name)
			}
		case *ast.Ident:
			t.write(":av \"receiver\" (mo \"variable ref\" :av \"name\" \"%s\" :av \"type\" \"type\")", fun.Name)
			t.write(":av \"name\" \"%s\"", fun.Name)
		default:
			t.logUnknown("UNKNOWN_CALL_FUN: %T", fun)
			t.visitNode(fun)
		}

		t.write(":av \"type\" \"type\"")
		t.indent--
		t.write(")")

		// Аргументы
		if len(n.Args) > 0 {
			for _, arg := range n.Args {
				t.visitNode(arg)
			}
			t.write(":av \"arguments\" (list %s)", t.formatExprs(n.Args))
		}

		t.write(":av \"type\" \"type\"")
		t.indent--
		t.write(")")

	case *ast.AssignStmt:
		t.write("(mo \"assignment stmt\"")
		t.indent++
		t.write(":av \"op\" \"%s\"", n.Tok.String())

		for _, expr := range n.Lhs {
			t.visitNode(expr)
		}
		t.write(":av \"1\" (list %s)", t.formatExprs(n.Lhs))

		for _, expr := range n.Rhs {
			t.visitNode(expr)
		}
		t.write(":av \"2\" (list %s)", t.formatExprs(n.Rhs))

		t.indent--
		t.write(")")

	case *ast.ExprStmt:
		t.visitNode(n.X)

	case *ast.BasicLit:
		// Числа и строки обрабатываются в formatExpressions

	case *ast.StarExpr:
		t.visitNode(n.X)

	default:
		t.logUnknown("UNKNOWN_NODE: %T at line %d", n, n.Pos())
		t.write("(mo \"UNKNOWN\" :av \"type\" \"%T\")", n)
	}
}

func (t *Translator) isTypeIdentifier(name string) bool {
	switch name {
	case "int", "string", "bool", "float64", "float32", "byte", "rune":
		return true
	default:
		return false
	}
}

func (t *Translator) getTypeString(expr ast.Expr) string {
	switch e := expr.(type) {
	case *ast.Ident:
		return t.formatType(e.Name)
	case *ast.StarExpr:
		return t.getTypeString(e.X)
	default:
		t.logUnknown("UNKNOWN_TYPE: %T at line %d", e, e.Pos())
		return "\"UNKNOWN_TYPE\""
	}
}

func (t *Translator) formatType(name string) string {
	switch name {
	case "int":
		return "\"int type\""
	case "string":
		return "\"string type\""
	case "bool":
		return "\"bool type\""
	default:
		t.logUnknown("UNKNOWN_TYPE_NAME: %s", name)
		return "\"UNKNOWN_TYPE\""
	}
}

func (t *Translator) formatNames(names []string) string {
	quoted := make([]string, len(names))
	for i, name := range names {
		quoted[i] = "\"" + name + "\""
	}
	return strings.Join(quoted, " ")
}

func (t *Translator) formatExprs(exprs []ast.Expr) string {
	var parts []string
	for _, expr := range exprs {
		switch e := expr.(type) {
		case *ast.Ident:
			parts = append(parts, "(mo \"variable ref\" :av \"name\" \""+e.Name+"\" :av \"type\" \"type\")")
		case *ast.BasicLit:
			if e.Kind.String() == "INT" {
				parts = append(parts, e.Value)
			} else {
				parts = append(parts, "\""+e.Value+"\"")
			}
		default:
			t.logUnknown("UNKNOWN_EXPR_IN_LIST: %T", e)
			parts = append(parts, "UNKNOWN")
		}
	}
	return strings.Join(parts, " ")
}

func (t *Translator) formatExpressions(exprs []ast.Expr) string {
	var parts []string
	for _, expr := range exprs {
		switch e := expr.(type) {
		case *ast.BasicLit:
			if e.Kind.String() == "INT" {
				parts = append(parts, e.Value)
			} else {
				parts = append(parts, "\""+e.Value+"\"")
			}
		default:
			t.logUnknown("UNKNOWN_EXPR_IN_VALUES: %T", e)
			parts = append(parts, "UNKNOWN")
		}
	}
	return strings.Join(parts, " ")
}

func ConvertFile(filename, outputDir string) error {
	if _, err := os.Stat(filename); os.IsNotExist(err) {
		return fmt.Errorf("file '%s' not found in current directory", filename)
	}

	fmt.Println("Processing file:", filename)

	fset := token.NewFileSet()

	file, err := parser.ParseFile(fset, filename, nil, parser.ParseComments)
	if err != nil {
		return fmt.Errorf("error parsing file: %w", err)
	}

	rawAstPath := filepath.Join(outputDir, "rawAst.txt")
	rawAstFile, err := os.Create(rawAstPath)
	if err != nil {
		return fmt.Errorf("error creating rawAst.txt: %w", err)
	}
	defer rawAstFile.Close()

	// ast.Fprint печатает AST в формате, который показывает все поля узлов
	err = ast.Fprint(rawAstFile, fset, file, nil)
	if err != nil {
		return fmt.Errorf("Error writing raw AST: %w", err)
	}
	fmt.Println("📄 Raw AST saved to rawAst.txt")

	translator := &Translator{}

	// Единый проход по дереву
	translator.visitNode(file)

	// Запись output.lisp
	outputPath := filepath.Join(outputDir, "output.lisp")
	err = os.WriteFile(outputPath, []byte(translator.output.String()), 0644)
	if err != nil {
		return fmt.Errorf("Error writing output: %w", err)
	}

	// Запись лога неизвестных узлов
	if translator.unknownLog.Len() > 0 {
		unknownNodesPath := filepath.Join(outputDir, "unknown_nodes.log")
		err = os.WriteFile(unknownNodesPath, []byte(translator.unknownLog.String()), 0644)
		if err != nil {
			return fmt.Errorf("Error writing unknown log: %w", err)
		}
		fmt.Println("\n⚠️  Unknown nodes found! Check unknown_nodes.log")
		fmt.Print(translator.unknownLog.String())
	}

	fmt.Println("\n✅ Successfully translated to output.lisp")
	fmt.Println("📄 AST tree saved to ast.txt")

	return nil
}
