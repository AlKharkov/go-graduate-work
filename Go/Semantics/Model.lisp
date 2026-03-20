#|
	Model of the Go language

	Last edit: 20/03/2026
|#


;;; Names
(typedef "identifier" (uniont string))
(typedef "variable name" "identifier")
(typedef "field name" "identifier")
(typedef "function name" "identifier")
(typedef "method name" "identifier")
(typedef "interface name" "identifier")
(typedef "label name" "identifier")
(typedef "type name" "identifier")
(typedef "package name" "identifier")


;;; Values and locations
(mot "location" :at "type" "type" :at "value" "Go value")  ; Simulates a memory location
(typedef "Go value" (uniont "literal" "location"))  ; Location simulates a pointer to location value
;;constants
(typedef "constant" (uniont "true" "false" int real "complex constant" string symbol))
(mot "complex constant" :at "re" real :at "im" real)
;;literals
(typedef "literal" (uniont "constant" "composite lit" "function lit" "channel lit"))
(typedef "composite lit" (uniont "array lit" "slice lit" "struct lit" "map lit"))  ; It construct new values for structs, arrays, slices, and maps
(mot "array lit" :at "type" "array type" :at "value" (listt "Go value"))
(mot "slice lit" :at "type" "slice type" :at "value" (listt "Go value"))
(mot "struct lit" :at "type" "struct type" :at "value" (cot :amap "field name" "Go value"))
(mot "map lit" :at "type" "map type" :at "value" (cot :amap "identifier" "Go value"))
;;function literals
(mot "function lit" :at "signature" "signature" :at "body" "block")  ; func(a int) bool { return a < 0 }
(mot "signature" :at "parameters" (listt "parameter decl") :at "variadic parameter" "variadic decl" :at "result" "function result")
(mot "parameter decl" :at "name" "identifier" :at "type" "type")
(mot "variadic decl" :at "name" "identifier" :at "type" "type")  ; func f(n ...int){}(1, 2, 3)
(mot "function result" :at "result" (uniont (listt "type") (listt "parameter decl")))
;;channel literals
(mot "channel lit" :at "type" "channel type" :at "cap" nat :at "buffer" (listt "Go value"))

;;; Types
(typedef "type" (uniont "base type" "composite type"))
(typedef "base type" (uniont "boolean type" "numeric type" "rune type" "string type"))
(typedef "boolean type" (enumt "bool"))
(typedef "numeric type" (uniont "int type" "float type" "complex type"))
(typedef "int type" (uniont "int" "int8" "int16" "int32" "int64" "uint" "uint8" "uint16" " uint32" "uint64" "uintptr" "byte"))
(typedef "float type" (enumt "float32" "float64"))
(typedef "complex type" (enumt "complex64" "complex128"))
(typedef "rune type" (enumt "rune"))  ; 'a' | '\t' | '\U00101234'
(typedef "string type" (enumt "string"))
;;composite types
(typedef "composite type" (uniont "array type" "slice type" "struct type" "pointer type" "function type" "interface type" "map type" "channel type"))
(mot "array type" :at "len" nat :at "element type" "type")  ; var a [2]int | [2][2]int ~ [2]([2]int)
(mot "slice type" :at "element type" "type")  ; var s []int
(mot "struct type" :at "fields" (cot :amap "field name" "type"))
(mot "pointer type" :at "type" "type")
;;function types
(mot "function type" :at "type signature" "type signature")
(mot "type signature" :at "types" (listt "type") :at "variadic type" "type" :at "result" (listt "type"))
(mot "interface type" :at "elements" (cot :amap "method name" "signature"))
; type A interface {
;   f(n int)     // "method name" = `f`, "signature" = `(n int)`
; }
(mot "map type" :at "key type" "type" :at "element type" "type")  ; map[string]int
(mot "channel type" :at "direction" "direction" :at "type" "type")
(typedef "direction" (enumt "bidirectional" "send" "receive"))
; chan T            // can be used to send and receive values of type T
; chan<- float64    // can only be used to send float64s
; <-chan int        // can only be used to receive ints


;;; Blocks
(mot "block"
	:at "statements" (listt "statement")
	; semantic attributes
	:at "variable location" (cot :amap "variable name" "location")  ; Старые ячейки иницилизируемых в блоке переменных, nil - если не существовали ранее
	:at "label position" (cot :amap "label" nat)  ; Позиции встречаемых в блоке меток
)


;;; Declarations
(typedef "declaration" (uniont "type decl" "var decl" "function decl" "method decl" "interface decl"))
(mot "type decl" :at "name" "type name" :at "type" "type")
; type Point struct{ x bool }  // Point and struct{ x bool } are different types
(mot "var decl" :amap "variable name" "type & value")  ; var x float64 = math.Sin(0)
(mot "type & value" :at "value" "expression" :at "type" "type")
;;function declarations
(mot "function decl" :at "name" "function name" :at "signature" "signature" :at "body" "block")
; func add(p *Point, q *Point) {
;   p.x += q.x
; }
(mot "method decl" :at "receiver" "parameter decl" :at "name" "method name" :at "signature" "signature" :at "body" "block")
; func (p *Point) add(q *Point) {
; 	p.x += q.x
; }
(mot "interface decl" :at "name" "interface name" :at "type" "interface type")


;;; Expressions
(typedef "expression" (uniont "literal" "conversion" "method expr" "selector expr" "index expr" "slice expr" "type assertion" "function call" "unary expression" "binary expression"))
(mot "conversion" :at "type" "type" :at "expression" "expression")  ; float64(2) == 2.0
(mot "method expression" :at "receiver type" "type" :at "name" "method name")
; type T struct { a int }
; func (t T) f(b int) int { return t.a + b }
; var t T = T{a: 2}    // t.f(1) ~ T.f(t, 1)
(typedef "selector expression" (uniont "selector struct" "selector method"))
(mot "selector struct" :at "struct" "expression" :at "field" "field name")  ; person.Age
(mot "selector method" :at "method" "expression" :at "method" "method name")  ; file.Close()
(mot "index expr" :at "arr" "expression" :at "index" "expression")  ; arr[0] | slice[1] | m["2"] | s[3]
(mot "slice expr" :at "arr" "expression" :at "low" "expression" :at "high" "expression" :at "max" "expression")  ; arr[low : high : max] | slice[low : high : max]
(mot "type assertion" :at "interface" "expression" :at "type" "type")  ; i.(Type)
; var i interface{} = 3
; num := i.(int) // Успех: num = 3 (тип int)
(mot "function call" :at "function" "expression" :at "arguments" (listt "expression"))  ; min(1, 2)
(mot "<-1" :at 1 "expression")  ; Return the value from the channel 1
;;unary expressions
(typedef "unary expression" (uniont "+1" "-1" "^1" "!1" "*1" "&1"))
(mot "+1" :at 1 "expression")  ; +x == x
(mot "-1" :at 1 "expression")  ; -x == -1 * x
(mot "^1" :at 1 "expression")  ; ^10(2) == 01(2)
(mot "!1" :at 1 "expression")  ; !true == false
(mot "*1" :at 1 "expression")
(mot "&1" :at 1 "expression")
;;binary expressions
(typedef "binary expression" (uniont "1||2" "1&&2" "1*2" "1/2" "1%2" "1<<2" "1>>2" "1&2" "1&^2" "1+2" "1-2" "1|2" "1^2" "1=2" "1!2" "1<2" "1<2" "1>2" "1>2"))
(mot "1||2" :at 1 "expression" :at 2 "expression")
(mot "1&&2" :at 1 "expression" :at 2 "expression")
(mot "1*2" :at 1 "expression" :at 2 "expression")
(mot "1/2" :at 1 "expression" :at 2 "expression")
(mot "1%2" :at 1 "expression" :at 2 "expression")
(mot "1<<2" :at 1 "expression" :at 2 "expression")
(mot "1>>2" :at 1 "expression" :at 2 "expression")
(mot "1&2" :at 1 "expression" :at 2 "expression")
(mot "1&^2" :at 1 "expression" :at 2 "expression") ; 1 &^ 2 == 1 & (^2)
(mot "1+2" :at 1 "expression" :at 2 "expression")
(mot "1-2" :at 1 "expression" :at 2 "expression")
(mot "1|2" :at 1 "expression" :at 2 "expression")
(mot "1^2" :at 1 "expression" :at 2 "expression")
(mot "1==2" :at 1 "expression" :at 2 "expression")
(mot "1!=2" :at 1 "expression" :at 2 "expression")
(mot "1<2" :at 1 "expression" :at 2 "expression")
(mot "1<=2" :at 1 "expression" :at 2 "expression")
(mot "1>2" :at 1 "expression" :at 2 "expression")
(mot "1>=2" :at 1 "expression" :at 2 "expression")


;;; Statements
(typedef "statement" (uniont "declaration" "label stmt" "empty stmt" "1++" "1--" "assignment stmt" "if stmt" "switch stmt" "for stmt" "return stmt" "break stmt" "continue stmt" "goto stmt" "go stmt" "1<-2" "fallthrough stmt" "select stmt" "defer stmt"))
(mot "label stmt" :at "label" "label name" :at "statement" "statement")
(typedef "empty stmt")  ; The empty statement does nothing
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
(mot "if stmt" :at "init" "statement" :at "condition" "expression" :at "then" "block" :at "else" (uniont "if statement" "block"))
; if x := f(); x < y {
; 	return x, true
; } else if x > y {
; 	return y, true
; }
;;switch statement
(typedef "switch stmt" (uniont "expr switch stmt" "type switch stmt"))
(mot "expr switch stmt" :at "init" "statement" :at "controlling expression" "expression" :at "cases" (listt "expr case clause"))
(mot "expr case clause" :at "cases" (uniont (listt "expression") "default") :at "statements" (listt "statement"))
(cot "default")
; switch a {
; case 0, 1, 2: f()
; default: g()
; }
(mot "type switch stmt" :at "init" "statement" :at "guard" "type switch guard" :at "cases" (listt "type case clause"))
(mot "type switch guard" :at "name" "identifier" :at "variable" "expression")
(mot "type case clause" :at "cases" (uniont (listt "type") "default") :at "statements" (listt "statement"))
; switch t := x.(type) {              // type checker
; case nil:
; 	fmt.Println("x is nil")  
; default:
;   fmt.Println("don't know the type")
;;for statement
(typedef "for statement" (uniont "for condition" "for range"))
(mot "for condition" :at "init" "statement" :at "condition" "expression" :at "post" "statement" :at "body" "block")
(mot "for range" :at "names" (listt (uniont "expression" "identifier")) :at "arr" "expression" :at "body" "block")  ; arr: array | slice | string | map | channel
; for x < y { a *= 2 }                // This is usually called a while loop.
; for i := 0; i < 10; i++ { f(i) }
; a := [5]int{1, 2, 3, 4, 5}
; for i, v := range a {               // for statement with range clause
;   fmt.Println(i, v)                 // i a[i]
; }
(mot "return" :at "expressions" (listt "expression"))
(mot "break " :at "label" "label")
(mot "continue" :at "label" "label")
(mot "goto" :at "label" "label")
;;goroutines and channels
(mot "go stmt" :at "body" "expression")  ; It starts the execution of a function call as an independent concurrent thread of control
(mot "1<-2" :at 1 "expression")  ; Adds value 2 to channel 1
(mot "select stmt" :at "statement" (listt "common clause"))
(mot "common clause" :at "case" (uniont "send stmt" "recive = stmt" "receive := stmt" "default") :at "statements" (listt "statement"))
(mot "receive = stmt" :at "names" (listt "expression") : at "expression" "expression")
(mot "receive := stmt" :at "names" (listt "identifier") : at "expression" "expression")
; ch1, ch2 := make(chan string), make(chan string)
; go func() { time.Sleep(1 * time.Second); ch1 <- "данные из канала 1" }()
; go func() { time.Sleep(2 * time.Second); ch2 <- "данные из канала 2" }()
; select {
; case msg1 := <-ch1: fmt.Println("Получено:", msg1)
; case msg2 := <-ch2: fmt.Println("Получено:", msg2)
; }
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
