#|
	Model of the Go language

	Last edit: 24/10/2025
|#


;;; Lexical elements
(mot "line comment" :at "text" string)     ; // single-line comment
(mot "general comment" :at "text" string)  ; /* multi-line comment */
(typedef "identifier" (uniont string))     ; a | _x9 | ThisVariableIsExported | αβ


;;; Constants
(typedef "constant" (uniont "bool constant" "numeric constant" string))
(typedef "bool constant" (enumt "true" "false"))
(typedef "numeric constant" (uniont int real "complex constant"))
(mot "complex constant" :at "re" real :at "im" real)


;;; Variables
(mot "variable" :at "value" "identifier")


;;; Types
(typedef "type" (uniont "base type" "composite type"))
(typedef "base type" (uniont "boolean type" "numeric type" "string type" "rune type"))
(typedef "boolean type" (enumt "bool"))
(typedef "numeric type" (uniont "real-valued type" "complex type" "byte type"))
(typedef "real-valued type" (enumt "int type" "float type"))
(typedef "int type" (uniont "signed int type" "unsigned int type"))
(typedef "signed int type" (enumt "int" "int8" "int16" "int32" "int64"))
(typedef "unsigned int type" (enumt "uint" "uint8" "uint16" " uint32" "uint64" "uintptr"))
(typedef "float type" (enumt "float32" "float64"))
(typedef "complex type" (enumt "complex32" "complex64"))
(typedef "byte type" (enumt "byte"))      ; <doc> alias for uint8
(typedef "rune type" (enumt "rune"))      ; 'a' | 'ä' | '本' | '\t' | '\377' | '\U00101234'
(typedef "string type" (enumt "string"))  ; "string" | `string`
;;composite types
(typedef "composite type" (uniont "array type" "slice type" "struct type" "pointer type" "function type" "interface type" "map type" "channel type"))
(mot "array type" :at "len" nat :at "element type" "type")  ; [32]byte | [2][2][2]float64 ~ same as [2]([2]([2]float64))
(mot "slice type" :at "element type" "type")
; a := [5]int{1, 2, 3, 4, 5}    // a = [1, 2, 3, 4, 5] - underlying array
; s := a[1:4]                   // s = [2, 3, 4] - slice
(mot "struct type" :at "fields" (listt "field decl"))
(typedef "field decl" (uniont "named field" "embedded field"))
(mot "named field" :at "name" "identifier" :at "type" "type")
(mot "embedded field" :at "type" "type")
; struct {
; 	x, y int    // named field 
; 	A *[]int
;   T           // embedded field
; }
(mot "pointer type" :at "type" "type")
;;function types
(mot "function type" :at "signature" "signature")
(mot "signature" :at "parameters" "parameters" :at "result" "function result")
(typedef "parameters" (uniont (listt "parameter decl")))
(mot "paramater decl" :at "name" (listt "identifier") :at "type" (uniont "type" "variadic type"))
(mot "variadic type" :at "type" "type")  ; func f(numbers ...int) -> f(1, 2, 3, 4)
(typedef "function result" (uniont "parameters" "type"))
; func("parameters") "result"
; func(a, b int, z float32) bool
; func(int, int, float64) (bool, int) ~ same as func(_, _ int, _ float64) (bool, int)
; func(n int) func(p *T)
;;interface types
(mot "interface type" :at "elements" (listt "interface elem"))
(typedef "interface elem" (uniont "method elem" "type elem"))
(mot "method elem" :at "name" "identifier" :at "signature" "signature")
(typedef "type elem" (uniont (listt "type term")))
(typedef "type term" (uniont "type" "underlying type"))
; type A interface {
;   f(n int) (q bool)     // method elem: "name" = `f`, "signature" = `(n int) (q bool)`
; }
; type B interface {
;   A                     // type elem: includes methods of A in B's method set
;   g(p *int) (a int[]) 
; }
; interface {             // An interface representing all types with underlying type int that implement the String method.
; 	~int
; 	String() string
; }
(mot "underlying type" :at "type" "type")  ; ~Type
; type (    
;   // the underlying type of string, A1 and A2 is string
; 	A1 = string
; 	A2 = A1
;
;   // the underlying type of B1 and B2 is string; the underlying type of []B1, B3 and B4 is []B1
; 	B1 string
; 	B2 B1
; 	B3 []B1
; 	B4 B3
; )
(mot "map type" :at "key type" "type" :at "element type" "type")  ; map[*T]struct{ x, y float64 }
(mot "channel type" :at "direction" "direction" :at "type" "type")
(typedef "direction" (enumt "bidirectional" "send" "receive"))
; chan T            // can be used to send and receive values of type T
; chan<- float64    // can only be used to send float64s
; <-chan int        // can only be used to receive ints


;;; Blocks
(mot "block" :at "statements" (listt "statement"))


;;; Declarations
(typedef "declaration" (uniont "const decl" "type decl" "var decl"))
(typedef "top level decl" (uniont "declaration" "function decl" "method decl"))
;;const declarations
(mot "const decl" :at "specifications" (listt "const spec"))
(mot "const spec" :at "names" (listt "identifier") :at "type" "type" :at "initializers" (listt "expression"))
; const (
; 	size int64 = 1024
; 	eof        = -1       // untyped integer constant
; )
;;type declarations
(typedef "type decl" (uniont (listt (uniont "alias decl" "type def"))))
(mot "alias decl" :at "name" "identifier" :at "type parameters" "type parameters" :at "type" "type")
; type (
; 	nodeList = []*Node    // nodeList and []*Node are identical types
; 	Polar    = polar      // Polar and polar denote identical types
; )
; type set[P comparable] = map[P]bool
(mot "type def" :at "name" "identifier" :at "type parameters" "type parameters" :at "type" "type")
; type (
; 	Point struct{ x, y float64 }    // Point and struct{ x, y float64 } are different types
; 	polar Point                     // polar and Point denote different types
; )
; type TreeNode struct {
; 	left, right *TreeNode
; 	value        any
; }
(mot "type parameters" :at "param declarations" (listt "type param decl"))
(mot "type param decl" :at "names" (listt "identifier") :at "type constraint" "type constraint")
(mot "type constraint" :at "constraints" "type elem")  ; [T1 comparable, T2 any]
;;var declarations
(mot "var decl" :at "specifiers" (listt "var spec"))
(mot "var spec" :at "names" (listt "identifier") :at "type" "type" :at "expressions" (listt "expression"))
; var U, V, W float64
; var k = 0
; var x, y float32 = -1, -2
(mot "short var decl" :at "names" (listt "identifier") :at "expressions" (listt "expression"))
; f := func() int { return 7 }
;;function declarations
(mot "function decl" :at "name" "identifier" :at "type parameters" "type parameters" :at "signature" "signature" :at "body" "function body")
(mot "function body" :at "block" "block")
; func min[T ~int|~float64](x, y T) T {
; 	if x < y {
; 		return x
; 	}
; 	return y
; }
;;method declarations
(mot "method decl" :at "reciever" "parameters" :at "name" "identifier" :at "signature" "signature" :at "body" "function body")
; func (p *Point) Scale(factor float64) {
; 	p.x *= factor
; 	p.y *= factor
; }


;;; Expressions
;;operands
(typedef "operand" (uniont "literal" "parenthesized expression"))
(typedef "literal" (uniont "basic literal" "composite literal" "function literal"))
(typedef "basic literal" (uniont "constant"))
(mot "composite literal" :at "type" "literal type" :at "value" (listt "keyed element"))
(mot "keyed element" :at "key" "key" :at "element" "element")
(typedef "literal type" (uniont "struct type" "array type" "slice type" "map type" "short arr type"))
(mot "short arr type" :at "name" (uniont "identifier" "qualified identifier") :at "type args" (listt "type"))
(mot "qualified identifier" :at "package name" "identifier" :at "name" "identifier")  ; math.Sin
(typedef "key" (uniont "field name" "expression" (listt "keyed element")))
(typedef "element" (uniont "expression" (listt "keyed element")))
(mot "function literal" :at "signature" "signature" :at "body" "block")  ; func(a, b int, z float64) bool { return a*b < int(z) }
(mot "parenthesized expression" :at "expression" "expression")
;;primary expressions
(typedef "primary expression" (uniont "operand" "conversion" "method expr" "primary expr & selector" "primary expr & index expr" "primary expr & slice expr" "primary expr & type assertion" "primary expr & argument"))
(mot "conversion" :at "type" "type" :at "expression" "expression")  ; (*Point)(p)    // p is converted to *Point
(mot "method expression" :at "receiver type" "type" :at "name" "identifier")
; type T struct {
; 	a int
; }
; func (tv T) Mv(b int) int { return tv.a + b }    // value receiver
(mot "primary expr & selector" :at "primary expr" "primary expression" :at "selector" "selector")
(mot "selector" :at "name" "identifier")  ; x.id
(mot "primary expr & index expr" :at "primary expr" "primary expression" :at "index" "index")
(mot "index expr" :at "expression" "expression")  ; x[e]
(mot "primary expr & slice expr" :at "primary expr" "primary expression" :at "slice" "slice")
(mot "slice expr" :at "low" "expression" :at "high" "expression" :at "max" "expression")  ; x[e1 : e2] | x[e1 : e2 : e3]
(mot "primary expr & type assertion" :at "primary expr" "primary expression" :at "type assertion" "type assertion")
(mot "type assertion" :at "type" "type")  ; .(Type)
; var x interface{} = 7    // x has dynamic type int and value 7
; i := x.(int)             // i has type int and value 7
(mot "primary expr & arguments" :at "primary expr" "primary expression" :at "arguments" (listt "argument"))  ; math.Sin(2)
(mot "argument" :at "expressions" (listt "expression") :at "type" "type")
;;expressions
(typedef "expression" (uniont "unary expression" "binary expression"))
;;unary expressions
(typedef "unary expression" (uniont "primary expression" "+1" "-1" "^1" "!1" "*1" "&1" "<-"))
(mot "+1" :at 1 "expression")  ; +x == x
(mot "-1" :at 1 "expression")  ; -x == -1 * x
(mot "^1" :at 1 "expression")  ; ^10(2) == 01(2)
(mot "!1" :at 1 "expression")  ; !true == false
(mot "*1" :at 1 "expression")
(mot "&1" :at 1 "expression")
(mot "<-" :at "channel" "channel type")
;;binary expressions
(typedef "binary expression" (uniont "1||2" "1&&2" "rel expression" "add expression" "mul expression"))
(mot "1||2" :at 1 "expression" :at 2 "expression")
(mot "1&&2" :at 1 "expression" :at 2 "expression")
;;binary multiplication expressions
(typedef "mul expression" (uniont "1*2" "1/2" "1%2" "1<<2" "1>>2" "1&2" "1&^2"))
(mot "1*2" :at 1 "expression" :at 2 "expression")
(mot "1/2" :at 1 "expression" :at 2 "expression")
(mot "1%2" :at 1 "expression" :at 2 "expression")
(mot "1<<2" :at 1 "expression" :at 2 "expression")
(mot "1>>2" :at 1 "expression" :at 2 "expression")
(mot "1&2" :at 1 "expression" :at 2 "expression")
(mot "1&^2" :at 1 "expression" :at 2 "expression") ; 11001010(2) &^ 10101100(2) == 01000010(2)    // 1 <=> 1 &^ 0
;;binary addition expressions
(typedef "add expression" (uniont "1+2" "1-2" "1|2" "1^2"))
(mot "1+2" :at 1 "expression" :at 2 "expression")
(mot "1-2" :at 1 "expression" :at 2 "expression")
(mot "1|2" :at 1 "expression" :at 2 "expression")
(mot "1^2" :at 1 "expression" :at 2 "expression")
;;relation expressions
(typedef "rel expression" (uniont "1=2" "1!2" "unequality expression"))
(mot "1==2" :at 1 "expression" :at 2 "expression")
(mot "1!=2" :at 1 "expression" :at 2 "expression")
(typedef "unequality expression" (uniont "1<2" "1<2" "1>2" "1>2"))
(mot "1<2" :at 1 "expression" :at 2 "expression")
(mot "1<=2" :at 1 "expression" :at 2 "expression")
(mot "1>2" :at 1 "expression" :at 2 "expression")
(mot "1>=2" :at 1 "expression" :at 2 "expression")

;;; Statements
(typedef "statement" (uniont "declaration" "label stmt" "simple stmt" "go stmt" "return stmt" "break stmt" "continue stmt" "goto stmt" "fallthrough stmt" "block" "if stmt" "switch stmt" "select stmt" "for stmt" "defer stmt"))
(typedef "simple statement" (uniont "empty stmt" "expression stmt" "send stmt" "1++" "1--" "assignment stmt" "short var decl"))
(typedef "empty stmt")  ; The empty statement does nothing
(mot "label stmt" :at "label" "label" :at "statement" "statement")
(mot "label" :at "name" "identifier")
; "label": "statement"
;   Error: log.Panic("error encountered")
(mot "expression stmt" :at "expression" "expression")
; h(x+y)
; f.Close()
(mot "send stmt" :at "channel" "expression" :at "message" "expression")
(mot "1++ stmt" :at "1" "expression")  ; x += 1
(mot "1-- stmt" :at "1" "expression")  ; x -= 1
;;assignment statements
(typedef "assignment stmt" (uniont "1=2" "1+=2" "1-=2" "1|=2" "1^=2" "1*=2" "1/=2" "1%=2" "1<<=2" "1>>=2" "1&=2" "1&^=2"))
(mot "1=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1+=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1-=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1|=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1^=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1*=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1/=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1%=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1<<=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1>>=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1&=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1&^=2" :at 1 (listt "expression") :at 2 (listt "expression"))
;;if statement
(mot "if stmt" :at "init" "simple stmt" :at "condition" "expression" :at "then" "block" :at "else" (uniont "if statement" "block"))
; if x := f(); x < y {
; 	return x
; } else if x > z {
; 	return z
; }
;;switch statement
(typedef "switch stmt" (uniont "expr switch stmt" "type switch stmt"))
(mot "expr switch stmt" :at "init" "simple stmt" :at "controlling expression" "expression" :at "cases" (listt "expr case clause"))
(mot "expr case clause" :at "cases" (uniont (listt "expression") "default") :at "statements" (listt "statement"))
(mot "default")
; switch tag {
; case 0, 1, 2, 3: s1()
; case 4, 5, 6, 7: s2()
; default: s3()
; }
(mot "type switch stmt" :at "init" "simple stmt" :at "guard" "type switch guard" :at "cases" (listt "type case clause"))
(mot "type switch guard" :at "name" "identifier" :at "variable" "primary expression")
(mot "type case clause" :at "cases" (uniont (listt "type") "default") :at "statements" (listt "statement"))
; switch t := x.(type) {              // type checker
; case nil:
; 	fmt.Println("x is nil")  
; default:
;   fmt.Println("don't know the type")
;;for statement
(typedef "for statement" (uniont "for stmt with condition clause" "for stmt with range clause"))
(mot "for stmt with condition clause" :at "init" "simple stmt" :at "condition" "expression" :at "post" "simple stmt" :at "body" "block")
(mot "for stmt with range clause" :at "names" (uniont (listt "expression") (listt "identifier")) :at "expression" "expression" :at "body" "block")
; for x < y { a *= 2 }                // the usual while loop
; for i := 0; i < 10; i++ { f(i) }    // the usual for loop
; a := [5]int{1, 2, 3, 4, 5}
; for i, v := range a {
;   fmt.Println(i, v)                 // i a[i]
; }
(mot "go stmt" :at "body" "expression")  ; It starts the execution of a function call as an independent concurrent thread of control
; go Server()
; go func(ch chan<- bool) { for { sleep(10); ch <- true }} (c)
(mot "select stmt" :at "statement" (listt "common clause"))
(mot "common clause" :at "case" "common case" :at "statements" (listt "statement"))
(typedef "common case" (uniont "send stmt" "recive stmt" "default"))
(mot "recive stmt" :at "names" (uniont (listt "expression") (listt "identifier")) :at "expression" "expression")
; func f1(c1 chan int) {
; 	a := <-c1
; 	c1 <- a
; }
; func f2(c2 chan int) {
; 	b := <-c2
; 	c2 <- b
; }
; c1, c2 := make(chan int), make(chan int)
; go f1(c1)
; go f2(c2)
; c1 <- 3
; c2 <- 4
; select {
; case a := <-c1:
;   fmt.Println(1, a)
; case b := <-c2:
;   fmt.Println(2, b)
; }
(mot "return" :at "expressions" (listt "expression"))
(mot "break " :at "label" "label")
; OuterLoop:
;   for {
;     for {
;       break OuterLoop
;     }
;   }
(mot "continue" :at "label" "label")
(mot "goto" :at "label" "label")
(typedef "fallthrough" (enumt "fallthrough"))
; switch {                     // prints "true & false"
;   case true:
;     fmt.Print("true & ")
;     fallthrough              // It transfers control to the next case clause in a switch
;   case false:
;     fmt.Print("false")
; }
(mot "defer stmt" :at "expression" "expression")  ; A "defer" statement invokes a function whose execution is deferred to the moment the surrounding function returns
; for i := 0; i <= 3; i++ {    // prints 3 2 1 0
; 	defer fmt.Print(i)
; }


;;; Packages
(mot "source file" :at "package name" "identifier" :at "import decl" (listt "import package") :at "declarations" (listt "top level decl"))
;;import declaration
(mot "import package" :at "package name" "identifier" :at "path" "path")
(typedef "path" (uniont string))  ; import m "lib/math"


;;; External definitions
;(mot "translation unit" :at "declarations" (listt "external declaration"))  	; Что это и зачем?
;(typedef "external declaration" (uniont "function definition" "declaration"))  ; Что это и зачем?
(mot "function definition" :at "signature" "signature" :at "body" "block")


;;; Semantics constructs
(mot "location")
(typedef "go value" (uniont "constant" "location" "function definition"))
