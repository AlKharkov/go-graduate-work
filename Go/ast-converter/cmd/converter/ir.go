package main

import (
	"fmt"
	"strconv"
	"strings"
)

// maxInlineLength — максимальная длина однострочного вывода узла или списка.
const maxInlineLength = 80

// Node — узел промежуточного представления.
type Node struct {
	Name       string
	Attributes []Attribute
}

// Attribute — атрибут узла.
type Attribute struct {
	Key   string
	Value any
}

// ============================================================
// Конструкторы
// ============================================================

// N создаёт узел с именем и атрибутами.
func N(name string, attrs ...Attribute) *Node {
	return &Node{Name: name, Attributes: attrs}
}

// A создаёт атрибут.
func A(key string, value any) Attribute {
	return Attribute{Key: key, Value: value}
}

// L создаёт список как []any.
func L(items ...any) []any {
	return items
}

// ============================================================
// Вывод в Lisp
// ============================================================

// Render превращает IR в Lisp-текст.
func Render(root *Node) string {
	var w strings.Builder
	renderNode(&w, root, 0)
	w.WriteString("\n")
	return w.String()
}

func indent(w *strings.Builder, level int) {
	w.WriteString(strings.Repeat("  ", level))
}

// renderNode выводит узел.
// Если узел «короткий» (все атрибуты — примитивы или короткие узлы/списки,
// суммарная длина ≤ maxInlineLength), он выводится в одну строку.
// Иначе — многострочно, с отступами.
func renderNode(w *strings.Builder, n *Node, level int) {
	if inline, ok := tryInlineNode(n); ok {
		w.WriteString(inline)
		return
	}

	w.WriteString("(mo \"")
	w.WriteString(n.Name)
	w.WriteString("\"")

	for _, attr := range n.Attributes {
		w.WriteString("\n")
		indent(w, level+1)
		w.WriteString(":at \"")
		w.WriteString(attr.Key)
		w.WriteString("\" ")
		renderValue(w, attr.Value, level+1)
	}

	w.WriteString("\n")
	indent(w, level)
	w.WriteString(")")
}

// renderValue выводит значение атрибута.
// level — уровень отступа, на котором находится само значение.
func renderValue(w *strings.Builder, v any, level int) {
	switch val := v.(type) {
	case nil:
		w.WriteString("nil")
	case string:
		w.WriteString(strconv.Quote(val))
	case int:
		w.WriteString(strconv.Itoa(val))
	case int64:
		w.WriteString(strconv.FormatInt(val, 10))
	case float64:
		w.WriteString(strconv.FormatFloat(val, 'g', -1, 64))
	case complex128:
		w.WriteString(formatComplex(val))
	case bool:
		w.WriteString(strconv.FormatBool(val))
	case *Node:
		renderNode(w, val, level)
	case []any:
		renderList(w, val, level)
	default:
		panic(fmt.Sprintf("unhandled value type: %T (value: %+v)", v, v))
	}
}

// renderList выводит список.
// Если список «короткий» (все элементы — примитивы или короткие узлы/списки,
// суммарная длина ≤ maxInlineLength), он выводится в одну строку.
// Иначе — каждый элемент на новой строке, закрывающая скобка на новой строке.
func renderList(w *strings.Builder, items []any, level int) {
	if inline, ok := tryInlineList(items); ok {
		w.WriteString(inline)
		return
	}

	w.WriteString("(list")
	if len(items) == 0 {
		w.WriteString(")")
		return
	}

	for _, item := range items {
		w.WriteString("\n")
		indent(w, level+1)
		renderValue(w, item, level+1)
	}

	w.WriteString("\n")
	indent(w, level)
	w.WriteString(")")
}

// ============================================================
// Однострочный вывод
// ============================================================

// tryInlineNode пытается вывести узел в одну строку.
// Возвращает (строка, true), если узел можно вывести в одну строку.
func tryInlineNode(n *Node) (string, bool) {
	var sb strings.Builder
	sb.WriteString("(mo \"")
	sb.WriteString(n.Name)
	sb.WriteString("\"")

	for _, attr := range n.Attributes {
		sb.WriteString(" :at \"")
		sb.WriteString(attr.Key)
		sb.WriteString("\" ")
		if s, ok := tryInlineValue(attr.Value); ok {
			sb.WriteString(s)
		} else {
			return "", false
		}
		if sb.Len() > maxInlineLength {
			return "", false
		}
	}

	sb.WriteString(")")
	if sb.Len() > maxInlineLength {
		return "", false
	}
	return sb.String(), true
}

// tryInlineList пытается вывести список в одну строку.
func tryInlineList(items []any) (string, bool) {
	var sb strings.Builder
	sb.WriteString("(list")
	for _, item := range items {
		sb.WriteString(" ")
		if s, ok := tryInlineValue(item); ok {
			sb.WriteString(s)
		} else {
			return "", false
		}
		if sb.Len() > maxInlineLength {
			return "", false
		}
	}
	sb.WriteString(")")
	return sb.String(), true
}

// tryInlineValue пытается вывести значение в одну строку.
func tryInlineValue(v any) (string, bool) {
	switch val := v.(type) {
	case nil:
		return "nil", true
	case string:
		return strconv.Quote(val), true
	case int:
		return strconv.Itoa(val), true
	case int64:
		return strconv.FormatInt(val, 10), true
	case float64:
		return strconv.FormatFloat(val, 'g', -1, 64), true
	case complex128:
		return formatComplex(val), true
	case bool:
		return strconv.FormatBool(val), true
	case *Node:
		return tryInlineNode(val)
	case []any:
		return tryInlineList(val)
	default:
		return "", false
	}
}

// formatComplex форматирует complex128 в Lisp-совместимый вид.
// Например, (2+3i).
func formatComplex(c complex128) string {
	re := strconv.FormatFloat(real(c), 'g', -1, 64)
	im := strconv.FormatFloat(imag(c), 'g', -1, 64)
	if imag(c) < 0 {
		return fmt.Sprintf("(%s%si)", re, im) // im уже со знаком минус
	}
	return fmt.Sprintf("(%s+%si)", re, im)
}

// String для отладки через fmt.Printf("%v", node).
func (n *Node) String() string {
	var w strings.Builder
	renderNode(&w, n, 0)
	return w.String()
}
