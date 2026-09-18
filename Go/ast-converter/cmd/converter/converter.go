package main

import (
	"fmt"
	"go/ast"
	"go/constant"
	"go/parser"
	"go/token"
	"go/types"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// ============================================================
// Translator
// ============================================================

type Translator struct {
	info       *types.Info
	fset       *token.FileSet
	unknownLog strings.Builder
}

func (t *Translator) logUnknown(format string, args ...any) {
	t.unknownLog.WriteString(fmt.Sprintf(format, args...))
	t.unknownLog.WriteString("\n")
}

// ============================================================
// Семантические помощники
// ============================================================

func (t *Translator) typeString(typ types.Type) any {
	if typ == nil {
		return "UNKNOWN_TYPE"
	}

	switch tt := typ.(type) {
	case *types.Basic:
		return t.basicTypeNode(tt)
	case *types.Slice:
		return N("slice type", A("elem type", t.typeString(tt.Elem())))
	case *types.Array:
		return N("array type",
			A("elem type", t.typeString(tt.Elem())),
			A("len", int64(tt.Len())))
	case *types.Pointer:
		return N("pointer type", A("type", t.typeString(tt.Elem())))
	case *types.Map:
		return N("map type",
			A("key type", t.typeString(tt.Key())),
			A("elem type", t.typeString(tt.Elem())))
	case *types.Chan:
		dir := "both"
		switch tt.Dir() {
		case types.SendOnly:
			dir = "send"
		case types.RecvOnly:
			dir = "recv"
		}
		return N("channel type",
			A("elem type", t.typeString(tt.Elem())),
			A("dir", dir))
	case *types.Struct:
		fields := make([]any, 0, tt.NumFields())
		ordered := make([]any, 0, tt.NumFields())
		for i := 0; i < tt.NumFields(); i++ {
			f := tt.Field(i)
			fields = append(fields, N("field & type",
				A("name", f.Name()),
				A("type", t.typeString(f.Type()))))
			ordered = append(ordered, f.Name())
		}
		return N("struct type",
			A("fields", fields),
			A("ordered", ordered))
	case *types.Interface:
		methods := make([]any, 0, tt.NumMethods())
		for i := 0; i < tt.NumMethods(); i++ {
			m := tt.Method(i)
			sig := m.Type().(*types.Signature)
			methods = append(methods, N("method & type",
				A("name", m.Name()),
				A("type", t.methodTypeNode(sig))))
		}
		return N("interface type", A("methods", methods))
	case *types.Signature:
		if tt.Recv() != nil {
			return t.methodTypeNode(tt)
		}
		return t.functionTypeNode(tt)
	case *types.Named:
		return tt.Obj().Name()
	case *types.TypeParam:
		return tt.Obj().Name()
	case *types.Alias:
		// any, или другие алиасы — используем имя
		return tt.Obj().Name()
	case *types.Tuple:
		// разворачиваем в список типов
		result := make([]any, 0, tt.Len())
		for i := 0; i < tt.Len(); i++ {
			result = append(result, t.typeString(tt.At(i).Type()))
		}
		return result
	default:
		t.logUnknown("UNRENDERED_TYPE: %T (%s)", typ, typ.String())
		return typ.String()
	}
}

func (t *Translator) basicTypeNode(b *types.Basic) any {
	switch b.Kind() {
	case types.Bool:
		return N("bool type")
	case types.String:
		return N("string type")
	case types.Int:
		return N("int type", A("bit size", int64(64)))
	case types.Int8:
		return N("signed int type", A("bit size", int64(8)))
	case types.Int16:
		return N("signed int type", A("bit size", int64(16)))
	case types.Int32:
		return N("signed int type", A("bit size", int64(32)))
	case types.Int64:
		return N("signed int type", A("bit size", int64(64)))
	case types.Uint:
		return N("unsigned int type", A("bit size", int64(64)))
	case types.Uint8:
		return N("unsigned int type", A("bit size", int64(8)))
	case types.Uint16:
		return N("unsigned int type", A("bit size", int64(16)))
	case types.Uint32:
		return N("unsigned int type", A("bit size", int64(32)))
	case types.Uint64:
		return N("unsigned int type", A("bit size", int64(64)))
	case types.Uintptr:
		return N("unsigned int type", A("bit size", int64(64)))
	case types.Float32:
		return N("float type", A("bit size", int64(32)))
	case types.Float64:
		return N("float type", A("bit size", int64(64)))
	case types.Complex64:
		return N("complex type", A("bit size", int64(64)))
	case types.Complex128:
		return N("complex type", A("bit size", int64(128)))
	case types.UntypedBool:
		return N("bool type")
	case types.UntypedInt:
		return N("int type", A("bit size", int64(64)))
	case types.UntypedRune:
		return N("signed int type", A("bit size", int64(32)))
	case types.UntypedFloat:
		return N("float type", A("bit size", int64(64)))
	case types.UntypedComplex:
		return N("complex type", A("bit size", int64(128)))
	case types.UntypedString:
		return N("string type")
	case types.UntypedNil:
		return nil
	default:
		t.logUnknown("UNRENDERED_BASIC: %s (kind=%v)", b.Name(), b.Kind())
		return "UNKNOWN_TYPE"
	}
}

func (t *Translator) functionTypeNode(sig *types.Signature) *Node {
	if sig == nil {
		t.logUnknown("functionTypeNode: nil signature")
		return N("function type",
			A("param types", []any{}),
			A("result types", []any{}))
	}
	paramTypes := make([]any, 0, sig.Params().Len())
	for i := 0; i < sig.Params().Len(); i++ {
		paramTypes = append(paramTypes, t.typeString(sig.Params().At(i).Type()))
	}
	resultTypes := make([]any, 0, sig.Results().Len())
	for i := 0; i < sig.Results().Len(); i++ {
		resultTypes = append(resultTypes, t.typeString(sig.Results().At(i).Type()))
	}
	n := N("function type",
		A("param types", paramTypes),
		A("result types", resultTypes))
	if sig.Variadic() {
		last := sig.Params().At(sig.Params().Len() - 1).Type()
		if sl, ok := last.(*types.Slice); ok {
			n.Attributes = append(n.Attributes,
				A("variadic type", t.typeString(sl.Elem())))
		}
	}
	return n
}

func (t *Translator) methodTypeNode(sig *types.Signature) *Node {
	if sig == nil {
		t.logUnknown("methodTypeNode: nil signature")
		return N("method type",
			A("receiver type", "UNKNOWN_TYPE"),
			A("param types", []any{}),
			A("result types", []any{}))
	}
	paramTypes := make([]any, 0, sig.Params().Len())
	for i := 0; i < sig.Params().Len(); i++ {
		paramTypes = append(paramTypes, t.typeString(sig.Params().At(i).Type()))
	}
	resultTypes := make([]any, 0, sig.Results().Len())
	for i := 0; i < sig.Results().Len(); i++ {
		resultTypes = append(resultTypes, t.typeString(sig.Results().At(i).Type()))
	}
	n := N("method type",
		A("receiver type", t.typeString(sig.Recv().Type())),
		A("param types", paramTypes),
		A("result types", resultTypes))
	if sig.Variadic() {
		last := sig.Params().At(sig.Params().Len() - 1).Type()
		if sl, ok := last.(*types.Slice); ok {
			n.Attributes = append(n.Attributes,
				A("variadic type", t.typeString(sl.Elem())))
		}
	}
	return n
}

func (t *Translator) paramDeclNode(name string, typ types.Type) *Node {
	return N("param decl",
		A("type", t.typeString(typ)),
		A("name", name))
}

func (t *Translator) functionSignatureNode(sig *types.Signature) *Node {
	if sig == nil {
		t.logUnknown("functionSignatureNode: nil signature")
		return N("function signature",
			A("parameters", []any{}),
			A("results", []any{}))
	}
	params := make([]any, 0, sig.Params().Len())
	for i := 0; i < sig.Params().Len(); i++ {
		p := sig.Params().At(i)
		params = append(params, t.paramDeclNode(p.Name(), p.Type()))
	}

	attrs := []Attribute{
		A("parameters", params),
	}

	if sig.Variadic() {
		last := sig.Params().At(sig.Params().Len() - 1)
		if sl, ok := last.Type().(*types.Slice); ok {
			attrs = append(attrs, A("variadic",
				t.paramDeclNode(last.Name(), sl.Elem())))
		}
	}

	attrs = append(attrs, A("results", t.resultsNode(sig)))

	return N("function signature", attrs...)
}

func (t *Translator) methodSignatureNode(sig *types.Signature) *Node {
	if sig == nil {
		t.logUnknown("methodSignatureNode: nil signature")
		return N("method signature",
			A("receiver", N("param decl", A("type", "UNKNOWN_TYPE"), A("name", ""))),
			A("parameters", []any{}),
			A("results", []any{}))
	}
	params := make([]any, 0, sig.Params().Len())
	for i := 0; i < sig.Params().Len(); i++ {
		p := sig.Params().At(i)
		params = append(params, t.paramDeclNode(p.Name(), p.Type()))
	}

	attrs := []Attribute{
		A("receiver", t.paramDeclNode(sig.Recv().Name(), sig.Recv().Type())),
		A("parameters", params),
	}

	if sig.Variadic() {
		last := sig.Params().At(sig.Params().Len() - 1)
		if sl, ok := last.Type().(*types.Slice); ok {
			attrs = append(attrs, A("variadic",
				t.paramDeclNode(last.Name(), sl.Elem())))
		}
	}

	attrs = append(attrs, A("results", t.resultsNode(sig)))

	return N("method signature", attrs...)
}

// resultsNode возвращает либо список типов (безымянные), либо список param decl (именованные).
func (t *Translator) resultsNode(sig *types.Signature) []any {
	if sig.Results().Len() == 0 {
		return []any{}
	}

	// Проверяем, есть ли имена
	hasNames := false
	for i := 0; i < sig.Results().Len(); i++ {
		if sig.Results().At(i).Name() != "" {
			hasNames = true
			break
		}
	}

	results := make([]any, 0, sig.Results().Len())
	if hasNames {
		for i := 0; i < sig.Results().Len(); i++ {
			r := sig.Results().At(i)
			results = append(results, t.paramDeclNode(r.Name(), r.Type()))
		}
	} else {
		for i := 0; i < sig.Results().Len(); i++ {
			results = append(results, t.typeString(sig.Results().At(i).Type()))
		}
	}
	return results
}

// ============================================================
// Константы
// ============================================================

func (t *Translator) constValue(v constant.Value) any {
	if v == nil {
		return nil
	}
	switch v.Kind() {
	case constant.Bool:
		return constant.BoolVal(v) // bool

	case constant.Int:
		if i, ok := constant.Int64Val(v); ok {
			return i // int64
		}
		// слишком большое число — fallback на строку
		return v.ExactString()

	case constant.Float:
		if f, ok := constant.Float64Val(v); ok {
			return f // float64
		}
		return v.ExactString()

	case constant.String:
		return constant.StringVal(v) // string

	case constant.Complex:
		if re, ok := constant.Float64Val(constant.Real(v)); ok {
			if im, ok := constant.Float64Val(constant.Imag(v)); ok {
				return complex(re, im) // complex128
			}
		}
		return v.ExactString()

	default:
		t.logUnknown("UNRENDERED_CONST_KIND: %v", v.Kind())
		return nil
	}
}

func (t *Translator) exprValue(expr ast.Expr) constant.Value {
	if tv, ok := t.info.Types[expr]; ok && tv.Value != nil {
		return tv.Value
	}
	return nil
}

// ============================================================
// Выражения
// ============================================================

func (t *Translator) renderExpr(expr ast.Expr) any {
	if expr == nil {
		return nil
	}

	switch e := expr.(type) {
	case *ast.BasicLit:
		// Используем вычисленное значение из go/types, если есть
		if val := t.exprValue(e); val != nil {
			return t.constValue(val)
		}
		// Fallback: парсим вручную
		switch e.Kind {
		case token.INT:
			if i, err := strconv.ParseInt(e.Value, 0, 64); err == nil {
				return i
			}
			return e.Value
		case token.FLOAT:
			if f, err := strconv.ParseFloat(e.Value, 64); err == nil {
				return f
			}
			return e.Value
		case token.STRING:
			s, _ := strconv.Unquote(e.Value)
			return s
		case token.CHAR:
			// символ — это rune (int32), храним как int64
			if r, _, _, err := strconv.UnquoteChar(e.Value[1:len(e.Value)-1], '\''); err == nil {
				return int64(r)
			}
			return e.Value
		case token.IMAG:
			// мнимое число: "2i" — храним как complex128(0, 2)
			// go/types обычно даёт значение через Info.Types, но на всякий случай
			if c, err := strconv.ParseComplex(e.Value, 128); err == nil {
				return c
			}
			return e.Value
		default:
			t.logUnknown("UNKNOWN_BASIC_LIT: %s", e.Kind)
			return e.Value
		}

	case *ast.Ident:
		// nil — отдельная сущность
		if e.Name == "nil" {
			return N("nil value", A("type", t.typeString(t.exprType(e))))
		}
		// true / false — примитивы
		if e.Name == "true" {
			return true
		}
		if e.Name == "false" {
			return false
		}
		// iota — подставляем вычисленное значение
		if e.Name == "iota" {
			if tv, ok := t.info.Types[e]; ok && tv.Value != nil {
				return t.constValue(tv.Value)
			}
			t.logUnknown("IOTA_WITHOUT_VALUE")
			return nil
		}
		// _ — blank identifier, type = nil
		if e.Name == "_" {
			return N("variable ref",
				A("name", "_"),
				A("type", nil))
		}
		// Если это имя типа — возвращаем строку
		if obj := t.info.Uses[e]; obj != nil {
			if _, isType := obj.(*types.TypeName); isType {
				return e.Name
			}
		}
		// Обычная ссылка на переменную
		return N("variable ref",
			A("name", e.Name),
			A("type", t.typeString(t.exprType(e))))

	case *ast.ParenExpr:
		return N("(1)",
			A("1", t.renderExpr(e.X)),
			A("type", t.typeString(t.exprType(e))))

	case *ast.BinaryExpr:
		nodeName := "1" + e.Op.String() + "2"
		return N(nodeName,
			A("1", t.renderExpr(e.X)),
			A("2", t.renderExpr(e.Y)),
			A("type", t.typeString(t.exprType(e))))

	case *ast.UnaryExpr:
		nodeName := e.Op.String() + "1"
		return N(nodeName,
			A("1", t.renderExpr(e.X)),
			A("type", t.typeString(t.exprType(e))))

	case *ast.StarExpr:
		// *x — либо разыменование, либо тип *T
		if tv, ok := t.info.Types[e]; ok && tv.IsType() {
			return N("pointer type", A("type", t.typeString(tv.Type)))
		}
		return N("*1",
			A("1", t.renderExpr(e.X)),
			A("type", t.typeString(t.exprType(e))))

	case *ast.CallExpr:
		return t.renderCallExpr(e)

	case *ast.SelectorExpr:
		return t.renderSelectorExpr(e)

	case *ast.IndexExpr:
		return N("index expr",
			A("indexable", t.renderExpr(e.X)),
			A("index", t.renderExpr(e.Index)),
			A("type", t.typeString(t.exprType(e))))

	case *ast.SliceExpr:
		attrs := []Attribute{
			A("sequence", t.renderExpr(e.X)),
		}
		if e.Low != nil {
			attrs = append(attrs, A("low", t.renderExpr(e.Low)))
		}
		if e.High != nil {
			attrs = append(attrs, A("high", t.renderExpr(e.High)))
		}
		if e.Max != nil {
			attrs = append(attrs, A("max", t.renderExpr(e.Max)))
		}
		attrs = append(attrs, A("type", t.typeString(t.exprType(e))))
		return N("slice expr", attrs...)

	case *ast.TypeAssertExpr:
		// x.(type) — type switch guard, обрабатывается в type switch stmt
		if e.Type == nil {
			return N("type assertion",
				A("interface", t.renderExpr(e.X)),
				A("type", nil))
		}
		return N("type assertion",
			A("interface", t.renderExpr(e.X)),
			A("type", t.typeString(t.exprType(e))))

	case *ast.CompositeLit:
		return t.renderCompositeLit(e)

	case *ast.FuncLit:
		sig, ok := t.exprType(e).(*types.Signature)
		if !ok {
			t.logUnknown("FUNC_LIT_WITHOUT_SIGNATURE at line %d", e.Pos())
			return N("function lit",
				A("type", N("function type", A("param types", []any{}), A("result types", []any{}))),
				A("signature", N("function signature", A("parameters", []any{}), A("results", []any{}))),
				A("body", t.renderBlock(e.Body)))
		}
		return N("function lit",
			A("type", t.functionTypeNode(sig)),
			A("signature", t.functionSignatureNode(sig)),
			A("body", t.renderBlock(e.Body)))

	case *ast.KeyValueExpr:
		return N("key & elem",
			A("key", t.renderExpr(e.Key)),
			A("value", t.renderExpr(e.Value)))

	case *ast.Ellipsis:
		if e.Elt != nil {
			return t.renderExpr(e.Elt)
		}
		return "..."

	case *ast.ChanType:
		return t.typeString(t.exprType(e))

	case *ast.ArrayType:
		return t.typeString(t.exprType(e))

	case *ast.MapType:
		return t.typeString(t.exprType(e))

	case *ast.StructType:
		return t.typeString(t.exprType(e))

	case *ast.InterfaceType:
		return t.typeString(t.exprType(e))

	case *ast.FuncType:
		return t.typeString(t.exprType(e))

	default:
		t.logUnknown("UNRENDERED_EXPR: %T", expr)
		return N("UNKNOWN_EXPR", A("type", fmt.Sprintf("%T", expr)))
	}
}

func (t *Translator) renderCallExpr(e *ast.CallExpr) any {
	// Если Fun — это SelectorExpr, проверяем несколько случаев
	if sel, ok := e.Fun.(*ast.SelectorExpr); ok {
		// 1. x.M() — method call (Selections.Kind() == MethodVal)
		if selection := t.info.Selections[sel]; selection != nil {
			if selection.Kind() == types.MethodVal {
				args := make([]any, 0, len(e.Args))
				for _, arg := range e.Args {
					args = append(args, t.renderExpr(arg))
				}
				return N("method call",
					A("receiver", t.renderExpr(sel.X)),
					A("method", sel.Sel.Name),
					A("arguments", args),
					A("type", t.typeString(t.exprType(e))))
			}
		}

		// 2. fmt.Println(...) — вызов функции из пакета
		if id, ok := sel.X.(*ast.Ident); ok {
			if obj := t.info.Uses[id]; obj != nil {
				if pkgName, isPkg := obj.(*types.PkgName); isPkg {
					args := make([]any, 0, len(e.Args))
					for _, arg := range e.Args {
						args = append(args, t.renderExpr(arg))
					}
					return N("function call",
						A("function", N("package access",
							A("package", pkgName.Imported().Path()),
							A("name", sel.Sel.Name))),
						A("arguments", args),
						A("type", "UNKNOWN_TYPE"))
				}
			}
		}

		// 3. T.M() — method expr call (T — тип)
		if tv, ok := t.info.Types[sel.X]; ok && tv.IsType() {
			args := make([]any, 0, len(e.Args))
			for _, arg := range e.Args {
				args = append(args, t.renderExpr(arg))
			}
			return N("function call",
				A("function", N("method expr",
					A("receiver type", t.typeString(tv.Type)),
					A("name", sel.Sel.Name),
					A("type", t.typeString(t.exprType(e.Fun))))),
				A("arguments", args),
				A("type", t.typeString(t.exprType(e))))
		}
	}

	// 4. Обычный вызов функции — f(...)
	args := make([]any, 0, len(e.Args))
	for _, arg := range e.Args {
		args = append(args, t.renderExpr(arg))
	}
	return N("function call",
		A("function", t.renderExpr(e.Fun)),
		A("arguments", args),
		A("type", t.typeString(t.exprType(e))))
}

func (t *Translator) renderSelectorExpr(e *ast.SelectorExpr) any {
	// 1. Selections — самый точный путь: поле или метод
	if selection := t.info.Selections[e]; selection != nil {
		switch selection.Kind() {
		case types.FieldVal:
			return N("field access",
				A("receiver", t.renderExpr(e.X)),
				A("name", e.Sel.Name),
				A("type", t.typeString(t.exprType(e))))
		case types.MethodVal:
			return N("method access",
				A("receiver", t.renderExpr(e.X)),
				A("name", e.Sel.Name),
				A("type", t.typeString(t.exprType(e))))
		}
	}

	// 2. PkgName — доступ к имени из импортированного пакета: fmt.Println, os.Args
	if id, ok := e.X.(*ast.Ident); ok {
		if obj := t.info.Uses[id]; obj != nil {
			if pkgName, isPkg := obj.(*types.PkgName); isPkg {
				return N("package access",
					A("package", pkgName.Imported().Path()),
					A("name", e.Sel.Name))
			}
		}
	}

	// 3. T.M — method expr (T — тип, не значение)
	if tv, ok := t.info.Types[e.X]; ok && tv.IsType() {
		return N("method expr",
			A("receiver type", t.typeString(tv.Type)),
			A("name", e.Sel.Name),
			A("type", t.typeString(t.exprType(e))))
	}

	// 4. Fallback: Selections пуст (например, из-за ошибки типов).
	// Пробуем определить по типу выражения e.
	if typ := t.exprType(e); typ != nil {
		if _, isSig := typ.Underlying().(*types.Signature); isSig {
			t.logUnknown("UNRESOLVED_SELECTOR_METHOD: %s", e.Sel.Name)
			return N("method access",
				A("receiver", t.renderExpr(e.X)),
				A("name", e.Sel.Name),
				A("type", t.typeString(typ)))
		}
		t.logUnknown("UNRESOLVED_SELECTOR_FIELD: %s", e.Sel.Name)
		return N("field access",
			A("receiver", t.renderExpr(e.X)),
			A("name", e.Sel.Name),
			A("type", t.typeString(typ)))
	}

	// 5. Совсем ничего не знаем
	t.logUnknown("UNRESOLVED_SELECTOR_UNKNOWN: %s", e.Sel.Name)
	return N("field access",
		A("receiver", t.renderExpr(e.X)),
		A("name", e.Sel.Name),
		A("type", "UNKNOWN_TYPE"))
}

func (t *Translator) renderCompositeLit(e *ast.CompositeLit) any {
	typ := t.exprType(e)
	if typ == nil {
		t.logUnknown("COMPOSITE_LIT_WITHOUT_TYPE")
		return N("composite lit", A("type", "UNKNOWN"))
	}

	// typeStr — исходный тип (например, "Point"), а не Underlying
	typeStr := t.typeString(typ)
	// underlying — реальная структура для диспетчеризации case
	underlying := typ.Underlying()

	switch tt := underlying.(type) {
	case *types.Array:
		elems := make([]any, 0, len(e.Elts))
		for i, elt := range e.Elts {
			if kv, ok := elt.(*ast.KeyValueExpr); ok {
				idx, _ := constant.Int64Val(t.exprValue(kv.Key))
				elems = append(elems, N("index & elem",
					A("index", idx),
					A("value", t.renderExpr(kv.Value))))
			} else {
				elems = append(elems, N("index & elem",
					A("index", int64(i)),
					A("value", t.renderExpr(elt))))
			}
		}
		return N("array lit",
			A("type", typeStr),
			A("elements", elems))

	case *types.Slice:
		elems := make([]any, 0, len(e.Elts))
		for i, elt := range e.Elts {
			if kv, ok := elt.(*ast.KeyValueExpr); ok {
				idx, _ := constant.Int64Val(t.exprValue(kv.Key))
				elems = append(elems, N("index & elem",
					A("index", idx),
					A("value", t.renderExpr(kv.Value))))
			} else {
				elems = append(elems, N("index & elem",
					A("index", int64(i)),
					A("value", t.renderExpr(elt))))
			}
		}
		return N("slice lit",
			A("type", typeStr),
			A("elements", elems))

	case *types.Struct:
		fields := make([]any, 0, len(e.Elts))
		for i, elt := range e.Elts {
			if kv, ok := elt.(*ast.KeyValueExpr); ok {
				key, _ := kv.Key.(*ast.Ident)
				fields = append(fields, N("field & value",
					A("field", key.Name),
					A("value", t.renderExpr(kv.Value))))
			} else {
				fields = append(fields, N("field & value",
					A("field", tt.Field(i).Name()),
					A("value", t.renderExpr(elt))))
			}
		}
		return N("struct lit",
			A("type", typeStr),
			A("fields", fields))

	case *types.Map:
		elems := make([]any, 0, len(e.Elts))
		for _, elt := range e.Elts {
			if kv, ok := elt.(*ast.KeyValueExpr); ok {
				elems = append(elems, N("key & elem",
					A("key", t.renderExpr(kv.Key)),
					A("value", t.renderExpr(kv.Value))))
			}
		}
		return N("map lit",
			A("type", typeStr),
			A("elements", elems))

	default:
		t.logUnknown("UNRENDERED_COMPOSITE_TYPE: %T", typ)
		return N("composite lit", A("type", typeStr))
	}
}

func (t *Translator) exprType(expr ast.Expr) types.Type {
	if tv, ok := t.info.Types[expr]; ok {
		return tv.Type
	}
	return nil
}

// ============================================================
// Statements
// ============================================================

func (t *Translator) renderStmt(stmt ast.Stmt) any {
	if stmt == nil {
		return nil
	}

	switch s := stmt.(type) {
	case *ast.AssignStmt:
		return t.renderAssign(s)

	case *ast.ExprStmt:
		return t.renderExpr(s.X)

	case *ast.IncDecStmt:
		op := s.Tok.String()
		return N(op+" stmt", A("1", t.renderExpr(s.X)))

	case *ast.ReturnStmt:
		results := make([]any, 0, len(s.Results))
		for _, r := range s.Results {
			results = append(results, t.renderExpr(r))
		}
		return N("return stmt", A("1", results))

	case *ast.IfStmt:
		attrs := []Attribute{}
		if s.Init != nil {
			attrs = append(attrs, A("init", t.renderStmt(s.Init)))
		}
		attrs = append(attrs,
			A("condition", t.renderExpr(s.Cond)),
			A("then", t.renderBlock(s.Body)))
		if s.Else != nil {
			attrs = append(attrs, A("else", t.renderStmt(s.Else)))
		}
		return N("if stmt", attrs...)

	case *ast.ForStmt:
		return t.renderForStmt(s)

	case *ast.RangeStmt:
		return t.renderRangeStmt(s)

	case *ast.SwitchStmt:
		return t.renderSwitchStmt(s)

	case *ast.TypeSwitchStmt:
		return t.renderTypeSwitchStmt(s)

	case *ast.SelectStmt:
		return t.renderSelectStmt(s)

	case *ast.CaseClause:
		return t.renderCaseClause(s)

	case *ast.BranchStmt:
		return t.renderBranchStmt(s)

	case *ast.LabeledStmt:
		return N("label",
			A("name", s.Label.Name),
			A("statement", t.renderStmt(s.Stmt)))

	case *ast.BlockStmt:
		return t.renderBlock(s)

	case *ast.DeferStmt:
		return N("defer stmt", A("1", t.renderCallOrExpr(s.Call)))

	case *ast.GoStmt:
		return N("go stmt", A("1", t.renderCallOrExpr(s.Call)))

	case *ast.SendStmt:
		return N("1<-2",
			A("1", t.renderExpr(s.Chan)),
			A("2", t.renderExpr(s.Value)))

	case *ast.EmptyStmt:
		return N("empty stmt")

	case *ast.DeclStmt:
		// DeclStmt оборачивает GenDecl — обрабатываем как declaration
		if gen, ok := s.Decl.(*ast.GenDecl); ok {
			return t.renderGenDecl(gen)
		}
		t.logUnknown("UNRENDERED_DECL_STMT: %T", s.Decl)
		return N("UNKNOWN_DECL_STMT")

	default:
		t.logUnknown("UNRENDERED_STMT: %T at line %d", stmt, stmt.Pos())
		return N("UNKNOWN_STMT", A("type", fmt.Sprintf("%T", stmt)))
	}
}

func (t *Translator) renderAssign(s *ast.AssignStmt) any {
	// := обрабатывается как var decl
	if s.Tok == token.DEFINE {
		return t.renderShortVarDecl(s)
	}

	op := s.Tok.String()
	lhs := make([]any, 0, len(s.Lhs))
	for _, e := range s.Lhs {
		lhs = append(lhs, t.renderExpr(e))
	}
	rhs := make([]any, 0, len(s.Rhs))
	for _, e := range s.Rhs {
		rhs = append(rhs, t.renderExpr(e))
	}
	return N(op,
		A("1", lhs),
		A("2", rhs))
}

func (t *Translator) renderShortVarDecl(s *ast.AssignStmt) any {
	names := make([]any, 0, len(s.Lhs))
	for _, e := range s.Lhs {
		if id, ok := e.(*ast.Ident); ok {
			names = append(names, id.Name)
		}
	}
	values := make([]any, 0, len(s.Rhs))
	for _, e := range s.Rhs {
		values = append(values, t.renderExpr(e))
	}
	// Типы из Info.Defs
	typesList := make([]any, 0, len(s.Lhs))
	for _, e := range s.Lhs {
		if id, ok := e.(*ast.Ident); ok {
			if obj := t.info.Defs[id]; obj != nil {
				typesList = append(typesList, t.typeString(obj.Type()))
			}
		}
	}
	return N("var decl",
		A("names", names),
		A("types", typesList),
		A("values", values))
}

func (t *Translator) renderForStmt(s *ast.ForStmt) any {
	attrs := []Attribute{}
	if s.Init != nil {
		attrs = append(attrs, A("init", t.renderStmt(s.Init)))
	}
	if s.Cond != nil {
		attrs = append(attrs, A("condition", t.renderExpr(s.Cond)))
	}
	if s.Post != nil {
		attrs = append(attrs, A("post", t.renderStmt(s.Post)))
	}
	attrs = append(attrs, A("body", t.renderBlock(s.Body)))

	// Если нет init и post — это for condition
	if s.Init == nil && s.Post == nil {
		return N("for condition",
			A("condition", t.renderExpr(s.Cond)),
			A("body", t.renderBlock(s.Body)))
	}
	return N("for clause", attrs...)
}

func (t *Translator) renderRangeStmt(s *ast.RangeStmt) any {
	operation := "assign"
	if s.Tok == token.DEFINE {
		operation = "decl"
	}

	typ := t.exprType(s.X)
	if typ == nil {
		t.logUnknown("RANGE_WITHOUT_TYPE")
		return N("for range", A("body", t.renderBlock(s.Body)))
	}

	var keyName, valueName string
	if s.Key != nil {
		if id, ok := s.Key.(*ast.Ident); ok {
			keyName = id.Name
		}
	}
	if s.Value != nil {
		if id, ok := s.Value.(*ast.Ident); ok {
			valueName = id.Name
		}
	}

	switch tt := typ.Underlying().(type) {
	case *types.Array, *types.Slice:
		attrs := []Attribute{}
		if keyName != "" {
			attrs = append(attrs, A("index", keyName))
		}
		if valueName != "" {
			attrs = append(attrs, A("value", valueName))
		}
		attrs = append(attrs,
			A("op", operation),
			A("indexable", t.renderExpr(s.X)),
			A("body", t.renderBlock(s.Body)))
		return N("for range indexable", attrs...)

	case *types.Map:
		attrs := []Attribute{}
		if keyName != "" {
			attrs = append(attrs, A("key", keyName))
		}
		if valueName != "" {
			attrs = append(attrs, A("value", valueName))
		}
		attrs = append(attrs,
			A("op", operation),
			A("map", t.renderExpr(s.X)),
			A("body", t.renderBlock(s.Body)))
		return N("for range map", attrs...)

	case *types.Chan:
		attrs := []Attribute{}
		if valueName != "" {
			attrs = append(attrs, A("value", valueName))
		} else if keyName != "" {
			attrs = append(attrs, A("value", keyName))
		}
		attrs = append(attrs,
			A("op", operation),
			A("channel", t.renderExpr(s.X)),
			A("body", t.renderBlock(s.Body)))
		return N("for range channel", attrs...)

	case *types.Basic:
		// Различаем string и int
		switch tt.Kind() {
		case types.String:
			attrs := []Attribute{}
			if keyName != "" {
				attrs = append(attrs, A("index", keyName))
			}
			if valueName != "" {
				attrs = append(attrs, A("value", valueName))
			}
			attrs = append(attrs,
				A("op", operation),
				A("indexable", t.renderExpr(s.X)),
				A("body", t.renderBlock(s.Body)))
			return N("for range indexable", attrs...)

		case types.Int, types.Int8, types.Int16, types.Int32, types.Int64,
			types.Uint, types.Uint8, types.Uint16, types.Uint32, types.Uint64:
			attrs := []Attribute{}
			if valueName != "" {
				attrs = append(attrs, A("value", valueName))
			} else if keyName != "" {
				attrs = append(attrs, A("value", keyName))
			}
			attrs = append(attrs,
				A("op", operation),
				A("max", t.renderExpr(s.X)),
				A("body", t.renderBlock(s.Body)))
			return N("for range int", attrs...)

		default:
			t.logUnknown("UNRENDERED_RANGE_BASIC: %s", tt.Name())
			return N("for range", A("body", t.renderBlock(s.Body)))
		}

	default:
		t.logUnknown("UNRENDERED_RANGE_TYPE: %T", typ)
		return N("for range", A("body", t.renderBlock(s.Body)))
	}
}

func (t *Translator) renderSwitchStmt(s *ast.SwitchStmt) any {
	attrs := []Attribute{}
	if s.Init != nil {
		attrs = append(attrs, A("init", t.renderStmt(s.Init)))
	}
	if s.Tag != nil {
		attrs = append(attrs, A("controlled", t.renderExpr(s.Tag)))
	}
	cases := make([]any, 0, len(s.Body.List))
	for _, c := range s.Body.List {
		cases = append(cases, t.renderStmt(c))
	}
	attrs = append(attrs, A("cases", cases))
	return N("expr switch stmt", attrs...)
}

func (t *Translator) renderTypeSwitchStmt(s *ast.TypeSwitchStmt) any {
	attrs := []Attribute{}
	if s.Init != nil {
		attrs = append(attrs, A("init", t.renderStmt(s.Init)))
	}

	// Извлекаем value и name из s.Assign
	switch assign := s.Assign.(type) {
	case *ast.AssignStmt:
		if len(assign.Lhs) == 1 && len(assign.Rhs) == 1 {
			if id, ok := assign.Lhs[0].(*ast.Ident); ok {
				attrs = append(attrs, A("name", id.Name))
			}
			if ta, ok := assign.Rhs[0].(*ast.TypeAssertExpr); ok {
				attrs = append(attrs, A("value", t.renderExpr(ta.X)))
			}
		}
	case *ast.ExprStmt:
		if ta, ok := assign.X.(*ast.TypeAssertExpr); ok {
			attrs = append(attrs, A("value", t.renderExpr(ta.X)))
		}
	}

	cases := make([]any, 0, len(s.Body.List))
	for _, c := range s.Body.List {
		cases = append(cases, t.renderStmt(c))
	}
	attrs = append(attrs, A("cases", cases))
	return N("type switch stmt", attrs...)
}

func (t *Translator) renderCaseClause(s *ast.CaseClause) any {
	attrs := []Attribute{}

	if s.List == nil {
		attrs = append(attrs, A("cases", "default"))
	} else {
		cases := make([]any, 0, len(s.List))
		for _, e := range s.List {
			// Проверяем, тип это или выражение
			if tv, ok := t.info.Types[e]; ok && tv.IsType() {
				cases = append(cases, t.typeString(tv.Type))
			} else {
				cases = append(cases, t.renderExpr(e))
			}
		}
		attrs = append(attrs, A("cases", cases))
	}

	stmts := make([]any, 0, len(s.Body))
	for _, st := range s.Body {
		stmts = append(stmts, t.renderStmt(st))
	}
	attrs = append(attrs, A("statements", stmts))

	// Различаем expr case clause и type case clause
	// по родителю — но у нас нет родителя, поэтому смотрим на типы
	isType := false
	for _, e := range s.List {
		if tv, ok := t.info.Types[e]; ok && tv.IsType() {
			isType = true
			break
		}
	}
	if isType {
		return N("type case clause", attrs...)
	}
	return N("expr case clause", attrs...)
}

func (t *Translator) renderSelectStmt(s *ast.SelectStmt) any {
	cases := make([]any, 0, len(s.Body.List))
	for _, c := range s.Body.List {
		if cc, ok := c.(*ast.CommClause); ok {
			cases = append(cases, t.renderCommClause(cc))
		}
	}
	return N("select stmt", A("cases", cases))
}

func (t *Translator) renderCommClause(c *ast.CommClause) any {
	attrs := []Attribute{}

	if c.Comm == nil {
		attrs = append(attrs, A("case", "default"))
	} else {
		attrs = append(attrs, A("case", t.renderStmt(c.Comm)))
	}

	stmts := make([]any, 0, len(c.Body))
	for _, st := range c.Body {
		stmts = append(stmts, t.renderStmt(st))
	}
	attrs = append(attrs, A("statements", stmts))

	return N("common clause", attrs...)
}

func (t *Translator) renderBranchStmt(s *ast.BranchStmt) any {
	keyword := s.Tok.String()
	label := any(nil)
	if s.Label != nil {
		label = s.Label.Name
	}
	switch keyword {
	case "break":
		return N("break stmt", A("1", label))
	case "continue":
		return N("continue stmt", A("1", label))
	case "goto":
		return N("goto stmt", A("1", label))
	case "fallthrough":
		return N("fallthrough")
	default:
		t.logUnknown("UNRENDERED_BRANCH: %s", keyword)
		return N("UNKNOWN_BRANCH")
	}
}

func (t *Translator) renderCallOrExpr(e *ast.CallExpr) any {
	return t.renderCallExpr(e)
}

// ============================================================
// Declarations
// ============================================================

func (t *Translator) renderGenDecl(gen *ast.GenDecl) any {
	switch gen.Tok {
	case token.IMPORT:
		var decls []any
		for _, spec := range gen.Specs {
			if imp, ok := spec.(*ast.ImportSpec); ok {
				decls = append(decls, t.renderImportSpec(imp))
			}
		}
		if len(decls) == 1 {
			return decls[0]
		}
		return decls
	case token.VAR:
		return t.renderValueDecl(gen, "var decl")
	case token.CONST:
		return t.renderValueDecl(gen, "const decl")
	case token.TYPE:
		if len(gen.Specs) == 1 {
			if ts, ok := gen.Specs[0].(*ast.TypeSpec); ok {
				return t.renderTypeDecl(ts)
			}
		}
		// Несколько type в одном GenDecl — возвращаем список
		decls := make([]any, 0, len(gen.Specs))
		for _, spec := range gen.Specs {
			if ts, ok := spec.(*ast.TypeSpec); ok {
				decls = append(decls, t.renderTypeDecl(ts))
			}
		}
		return decls
	}
	return nil
}

func (t *Translator) renderImportSpec(imp *ast.ImportSpec) *Node {
	path, _ := strconv.Unquote(imp.Path.Value)

	var name string
	if imp.Name != nil {
		name = imp.Name.Name // алиас, "_", "."
	} else {
		name = path
		if idx := strings.LastIndex(path, "/"); idx >= 0 {
			name = path[idx+1:]
		}
	}

	return N("import decl",
		A("name", name),
		A("path", path))
}

func (t *Translator) renderValueDecl(gen *ast.GenDecl, kind string) any {
	// Если одна спецификация — возвращаем один узел
	// Если несколько — возвращаем список
	var decls []any
	for _, spec := range gen.Specs {
		vs, ok := spec.(*ast.ValueSpec)
		if !ok {
			continue
		}
		decls = append(decls, t.renderValueSpec(vs, kind))
	}
	if len(decls) == 1 {
		return decls[0]
	}
	return decls
}

func (t *Translator) renderValueSpec(vs *ast.ValueSpec, kind string) any {
	names := make([]any, 0, len(vs.Names))
	for _, id := range vs.Names {
		names = append(names, id.Name)
	}

	attrs := []Attribute{A("names", names)}

	if kind == "const decl" {
		// Для констант: значения из Info.Defs, типы не выводим (untyped)
		values := make([]any, 0, len(vs.Names))
		for _, id := range vs.Names {
			if obj := t.info.Defs[id]; obj != nil {
				if c, ok := obj.(*types.Const); ok {
					values = append(values, t.constValue(c.Val()))
				}
			}
		}
		attrs = append(attrs, A("values", values))
		return N(kind, attrs...)
	}

	// var decl: типы из Info.Defs
	typesList := make([]any, 0, len(vs.Names))
	for _, id := range vs.Names {
		if obj := t.info.Defs[id]; obj != nil {
			typesList = append(typesList, t.typeString(obj.Type()))
		} else {
			typesList = append(typesList, "UNKNOWN_TYPE")
		}
	}
	attrs = append(attrs, A("types", typesList))

	if len(vs.Values) > 0 {
		values := make([]any, 0, len(vs.Values))
		for _, e := range vs.Values {
			values = append(values, t.renderExpr(e))
		}
		attrs = append(attrs, A("values", values))
	}

	return N(kind, attrs...)
}

func (t *Translator) renderTypeDecl(ts *ast.TypeSpec) any {
	attrs := []Attribute{
		A("name", ts.Name.Name),
	}
	if obj := t.info.Defs[ts.Name]; obj != nil {
		typ := obj.Type()
		if named, ok := typ.(*types.Named); ok {
			typ = named.Underlying()
		}
		attrs = append(attrs, A("type", t.typeString(typ)))
	}
	return N("type decl", attrs...)
}

func (t *Translator) renderFuncDecl(fn *ast.FuncDecl) any {
	if fn.Recv != nil {
		return t.renderMethodDecl(fn)
	}

	attrs := []Attribute{
		A("name", fn.Name.Name),
	}

	if obj := t.info.Defs[fn.Name]; obj != nil {
		if f, ok := obj.(*types.Func); ok {
			sig := f.Type().(*types.Signature)
			attrs = append(attrs, A("value", N("function lit",
				A("type", t.functionTypeNode(sig)),
				A("signature", t.functionSignatureNode(sig)),
				A("body", t.renderBlock(fn.Body)))))
		}
	}

	return N("function decl", attrs...)
}

func (t *Translator) renderMethodDecl(fn *ast.FuncDecl) any {
	attrs := []Attribute{
		A("name", fn.Name.Name),
	}

	if obj := t.info.Defs[fn.Name]; obj != nil {
		if f, ok := obj.(*types.Func); ok {
			sig := f.Type().(*types.Signature)
			attrs = append(attrs, A("value", N("method lit",
				A("type", t.methodTypeNode(sig)),
				A("signature", t.methodSignatureNode(sig)),
				A("body", t.renderBlock(fn.Body)))))
		}
	}

	return N("method decl", attrs...)
}

// ============================================================
// Block
// ============================================================

func (t *Translator) renderBlock(b *ast.BlockStmt) *Node {
	if b == nil {
		return N("block", A("statements", []any{}))
	}

	stmts := make([]any, 0, len(b.List))
	for _, st := range b.List {
		rendered := t.renderStmt(st)
		if rendered == nil {
			continue
		}
		// Если renderStmt вернул список (несколько type decl), разворачиваем
		if list, ok := rendered.([]any); ok {
			stmts = append(stmts, list...)
		} else {
			stmts = append(stmts, rendered)
		}
	}

	return N("block", A("statements", stmts))
}

// ============================================================
// File
// ============================================================

func (t *Translator) renderFile(f *ast.File) *Node {
	decls := make([]any, 0, len(f.Decls))
	for _, decl := range f.Decls {
		var rendered any
		switch d := decl.(type) {
		case *ast.GenDecl:
			rendered = t.renderGenDecl(d)
		case *ast.FuncDecl:
			rendered = t.renderFuncDecl(d)
		default:
			t.logUnknown("UNRENDERED_DECL: %T", decl)
			continue
		}
		if rendered == nil {
			continue
		}
		if list, ok := rendered.([]any); ok {
			decls = append(decls, list...)
		} else {
			decls = append(decls, rendered)
		}
	}

	block := N("block", A("statements", decls))
	return N("file",
		A("package", f.Name.Name),
		A("block", block))
}

// ============================================================
// Entry point
// ============================================================

func ConvertFile(filename, outputDir string) error {
	if _, err := os.Stat(filename); os.IsNotExist(err) {
		return fmt.Errorf("file '%s' not found", filename)
	}

	fmt.Println("Processing file:", filename)

	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, filename, nil, parser.ParseComments)
	if err != nil {
		return fmt.Errorf("error parsing file: %w", err)
	}

	// Сохраняем сырое AST
	rawAstPath := filepath.Join(outputDir, "rawAst.txt")
	rawAstFile, err := os.Create(rawAstPath)
	if err != nil {
		return fmt.Errorf("error creating rawAst.txt: %w", err)
	}
	if err := ast.Fprint(rawAstFile, fset, file, nil); err != nil {
		rawAstFile.Close()
		return fmt.Errorf("error writing rawAst.txt: %w", err)
	}
	rawAstFile.Close()
	fmt.Println("📄 Raw AST saved to rawAst.txt")

	info := &types.Info{
		Defs:       make(map[*ast.Ident]types.Object),
		Uses:       make(map[*ast.Ident]types.Object),
		Types:      make(map[ast.Expr]types.TypeAndValue),
		Selections: make(map[*ast.SelectorExpr]*types.Selection),
	}

	conf := types.Config{}
	_, err = conf.Check(file.Name.Name, fset, []*ast.File{file}, info)
	if err != nil {
		fmt.Fprintln(os.Stderr, "⚠️  type check warning:", err)
	}

	translator := &Translator{info: info, fset: fset}

	// Строим IR
	root := translator.renderFile(file)

	// Выводим Lisp
	output := Render(root)

	outputPath := filepath.Join(outputDir, "abml_model.lisp")
	if err := os.WriteFile(outputPath, []byte(output), 0644); err != nil {
		return fmt.Errorf("error writing output: %w", err)
	}

	// Лог неизвестных узлов
	if translator.unknownLog.Len() > 0 {
		unknownPath := filepath.Join(outputDir, "unknown_nodes.log")
		if err := os.WriteFile(unknownPath, []byte(translator.unknownLog.String()), 0644); err != nil {
			return fmt.Errorf("error writing unknown log: %w", err)
		}
		fmt.Println("\n⚠️  Unknown nodes found! Check unknown_nodes.log")
		fmt.Print(translator.unknownLog.String())
	}

	fmt.Println("\n✅ Successfully translated to output.lisp")
	return nil
}
