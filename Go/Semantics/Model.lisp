#|
	Model of the Go language

	Last edit: 21/02/2026
|#


;;; Identifiers
(typedef "identifier" (uniont string))


;;; Constants
(typedef "constant" (uniont "bool constant" "numeric constant" string symbol))
(typedef "bool constant" (enumt "true" "false"))
(typedef "numeric constant" (uniont int real "complex constant"))
(mot "complex constant" :at "re" real :at "im" real)


;;; Types
(typedef "type" (uniont "base type" "composite type"))
(typedef "base type" (uniont "boolean type" "numeric type" "rune type" "string type"))
(typedef "boolean type" (enumt "bool"))
(typedef "numeric type" (uniont "int type" "float type" "complex type"))
(typedef "int type" (uniont "signed int type" "unsigned int type"))
(typedef "signed int type" (enumt "int" "int8" "int16" "int32" "int64"))
(typedef "unsigned int type" (enumt "uint" "uint8" "uint16" " uint32" "uint64" "uintptr" "byte"))
(typedef "float type" (enumt "float32" "float64"))
(typedef "complex type" (enumt "complex64" "complex128"))
(typedef "rune type" (enumt "rune"))  ; 'a' | '\t' | '本' | '\U00101234'
(typedef "string type" (enumt "string"))
;;composite types
(typedef "composite type" (uniont "array type" "slice type" "struct type" "pointer type" "function type" "interface type" "map type" "channel type"))
(mot "array type" :at "len" nat :at "element type" "type")  ; var a [2]int | [2][2]int ~ [2]([2]int)
(mot "slice type" :at "element type" "type")  ; var s []int
(mot "struct type" :at "fields" (cot :amap "identifier" "type"))
(mot "pointer type" :at "type" "type")
;;function types
(mot "function type" :at "signature" "signature")
(mot "signature" :at "parameters" (listt "parameter decl") :at "variadic parameter" "variadic decl" :at "result" "function result")
(mot "parameter decl" :at "name" "identifier" :at "type" "type")
(mot "variadic decl" :at "name" "identifier" :at "type" "type")  ; func f(n ...int){}(1, 2, 3)
(mot "function result" :at "result" (uniont "type" (listt "parameter decl")))
; func("parameters") "result"
; func(a int, b float32) bool
; func() (x bool, y int)
(mot "interface type" :at "elements" (listt "method elem"))
(mot "method elem" :at "name" "identifier" :at "signature" "signature")
; type A interface {
;   f(n int) (q bool)     // method elem: "name" = `f`, "signature" = `(n int) (q bool)`
; }
(mot "map type" :at "key type" "type" :at "element type" "type")  ; map[*T]struct{ x, y float64 }
(mot "channel type" :at "direction" "direction" :at "type" "type")
(typedef "direction" (enumt "bidirectional" "send" "receive"))
; chan T            // can be used to send and receive values of type T
; chan<- float64    // can only be used to send float64s
; <-chan int        // can only be used to receive ints


;;; Blocks
(mot "block"
	:at "statements" (listt "statement")
	; semantic attributes
	:at "variable location" (cot :amap "identifier" "location")  ; Старые ячейки иницилизируемых в блоке переменных, nil - если не существовали ранее
	:at "label position" (cot :amap "label" nat)  ; Позиции встречаемых в блоке меток
)


;;; Declarations
(typedef "declaration" (uniont "const decl" "type decl" "var decl"))
(mot "const decl" :amap "identifier" "const value")  ; const a int, b int = 1, 2
(mot "const value" :at "value" "constant" :at "type" "type")
(mot "type decl" :at "name" "identifier" :at "type" "type")
; type Point struct{ x bool }  // Point and struct{ x bool } are different types
(mot "var decl" :amap "identifier" "var value")  ; var x float64 = math.Sin(0)
(mot "var value" :at "value" "expression" :at "type" "type")
;;function declarations
(mot "function decl" :at "name" "identifier" :at "signature" "signature" :at "body" "block")
; func add(p *Point, q *Point) {
;   p.x += q.x
; }
(mot "method decl" :at "receiver" "parameter decl" :at "name" "identifier" :at "signature" "signature" :at "body" "block")
; func (p *Point) add(q *Point) {
; 	p.x += q.x
; }


;;; Expressions
;;operands
(typedef "operand" (uniont "literal" "(expression)"))
(typedef "literal" (uniont "constant" "composite literal" "function literal"))
(typedef "composite literal" (uniont "array lit" "slice lit" "struct lit" "map lit"))  ; It construct new values for structs, arrays, slices, and maps
(mot "array lit" :at "type" "array type" :at "value" (listt "Go value"))
(mot "slice lit" :at "type" "slice type" :at "value" (listt "Go value"))
(mot "struct lit" :at "type" "struct type" :at "value" (cot :amap "identifier" "Go value"))
(mot "map lit" :at "type" "map type" :at "value" (cot :amap "identifier" "Go value"))
(mot "function literal" :at "signature" "signature" :at "body" "block")  ; func(a int) bool { return a < 0 }
(mot "(expression)" :at "expression" "expression")
;;primary expressions
(typedef "primary expression" (uniont "operand" "conversion" "method expr" "selector expr" "index expr" "slice expr" "type assertion" "function call"))
(mot "conversion" :at "type" "type" :at "expression" "expression")  ; float64(2) == 2.0
(mot "method expression" :at "receiver type" "type" :at "name" "identifier")
; type T struct { a int }
; func (t T) f(b int) int { return t.a + b }
; var t T = T{a: 2}    // t.f(1) ~ T.f(t, 1)
(mot "selector expression" :at "expression" "primary expression" :at "selector" "identifier")  ; t.a
(mot "index expr" :at "list" "primary expression" :at "index" "expression")  ; s[0]
(mot "slice expr" :at "list" "primary expression" :at "slice" "slice")
(mot "slice" :at "low" "expression" :at "high" "expression" :at "max" "expression")  ; x[low : high : max]
(mot "type assertion" :at "expression" "primary expression" :at "type" "type")  ; .(Type)
; var x interface{} = 7    // x has dynamic type int and value 7
; i := x.(int)             // i has type int and value 7
(mot "function call" :at "function" (uniont "function lit" "identifier") :at "arguments" (listt "expression") :at "variadic argument" "expression")  ; min(1, 2)
;;expressions
(typedef "expression" (uniont "unary expression" "binary expression"))
;;unary expressions
(typedef "unary expression" (uniont "primary expression" "+1" "-1" "^1" "!1" "*1" "&1" "<-1"))
(mot "+1" :at 1 "unary expression")  ; +x == x
(mot "-1" :at 1 "unary expression")  ; -x == -1 * x
(mot "^1" :at 1 "unary expression")  ; ^10(2) == 01(2)
(mot "!1" :at 1 "unary expression")  ; !true == false
(mot "*1" :at 1 "unary expression")
(mot "&1" :at 1 "unary expression")
(mot "<-1" :at 1 "unary expression")  ; Pulls the value from the channel 1
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
(mot "1&^2" :at 1 "expression" :at 2 "expression") ; 1 &^ 2 == 1 & (^2)
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
(typedef "statement" (uniont "declaration" "labeled stmt" "simple stmt" "go stmt" "return stmt" "break stmt" "continue stmt" "goto stmt" "fallthrough stmt" "block" "if stmt" "switch stmt" "select stmt" "for stmt" "defer stmt"))
(mot "label stmt" :at "label" "label" :at "statement" "statement")
(mot "label" :at "name" "identifier")  ; "label": "statement"
(typedef "simple stmt" (uniont "empty stmt" "expression stmt" "send stmt" "1++" "1--" "assignment stmt"))
(typedef "empty stmt")  ; The empty statement does nothing
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
(cot "default")
; switch a {
; case 0, 1, 2: f()
; default: g()
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
(typedef "common case" (uniont "send stmt" "recive = stmt" "receive := stmt" "default"))
(mot "receive = stmt" :at "names" (listt "expression") : at "expression" "expression")
(mot "receive := stmt" :at "names" (listt "identifier") : at "expression" "expression")
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
(typedef "top level decl" (uniont "declaration" "function decl" "method decl"))
(mot "source file" :at "package name" "identifier" :at "import decl" (listt "import package") :at "declarations" (listt "top level decl"))
;;import declaration
(mot "import package" :at "package name" "identifier" :at "path" "path")
(typedef "path" (uniont string))  ; import m "lib/math"


;;; Semantics constructs
(mot "location" :at "type" "type" :at "value" "Go value")
(typedef "Go value" (uniont "literal" "location"))
