#|
     Model of the Go language

     Last edit: 18/09/2026
|#


;;; ================================================
;;; Names
;;; ================================================

(typedef "identifier"     string)
(typedef "constant name"  "identifier")
(typedef "variable name"  "identifier")
(typedef "field name"     "identifier")
(typedef "function name"  "identifier")
(typedef "parameter name" "identifier")
(typedef "method name"    "identifier")
(typedef "label name"     "identifier")
(typedef "type name"      "identifier")


;;; ================================================
;;; Types
;;; ================================================

(typedef "type" (uniont "primitive type" "composite type"))

(typedef "primitive type" (uniont "bool type" "string type" "numeric type"))

(cot "bool type")
(cot "string type")
(typedef "numeric type"  (uniont "int type" "float type" "complex type"))
(typedef "int type"      (uniont "signed int type" "unsigned int type"))
(cot "signed int type"   :at "bit size" (enumt 8 16 32 64))
(cot "unsigned int type" :at "bit size" (enumt 8 16 32 64))
(cot "float type"        :at "bit size" (enumt 32 64))
(cot "complex type"      :at "bit size" (enumt 64 128))

;; composite types
(typedef "composite type" (uniont "array type" "slice type" "struct type" 
                                  "pointer type" "function type" "method type"
                                  "interface type" "map type" "channel type"))

(cot "array type"   :at "elem type" "type" :at "len" nat)
(cot "slice type"   :at "elem type" "type")
(cot "struct type"  :at "fields"  (cot :amap "field name" "type")  ; does not support embedding
                    :at "ordered" (listt "field name"))  ; (static analysis attribute) for the unnamed initiation
(cot "pointer type" :at "type" "type")

;; function type omits parameter names (only types matter for type checking)
(cot "function type" 
     :at "param types"   (listt "type") 
     :at "variadic type" "type" ; nil if not variadic
     :at "result types"  (listt "type"))

(cot "method type" 
     :at "receiver type" "type" 
     :at "param types"   (listt "type") 
     :at "variadic type" "type" ; nil if not variadic
     :at "result types"  (listt "type"))

(cot "interface type" :at "methods"   (cot :amap "method name" "method type")) ; does not support embedded interfaces
(cot "map type"       :at "key type"  "type" :at "elem type" "type")
(cot "channel type"   :at "elem type" "type" :at "dir" (enumt "send" "recv" "both"))


;;; ================================================
;;; Cells and values
;;; ================================================

;; A cell is a mutable container that holds a Go value.
;; Variables are bound to cells, not directly to values.
(mot "cell" :at "value" "Go value")

;; There are no untyped constants at the operational semantics (runtime) phase.
(typedef "Go value" (uniont "nil value" "typed primitive" "composite value"))

;; untyped constant
(typedef "untyped constant" (uniont bool int real string complex))  ; (static analysis type)

;; typed value
(mot "typed primitive" 
     :at "type" "type"  ; filled by static analysis phase
     :at "value" "untyped constant")

;; nil is typed too; each reference type has its own typed nil
(mot "nil value" :at "type" "type")

;; composite value (reference typed store additional metadata)
(typedef "composite value" (uniont "array value" "slice value" "struct value" "map value" 
                                   "pointer value" "channel value" "function value" 
                                   "method value" "interface value"))

;; array stores elements inline; assignment copies the entire array
(mot "array value" 
     :at "type"     "array type" 
     :at "elements" (listt "cell"))

;; slice is a view into an array; multiple slices can share the same underlying array
(mot "slice value" 
     :at "type"     "slice type" 
     :at "array"    "array value" 
     :at "offset"   nat 
     :at "length"   nat 
     :at "capacity" nat)

(mot "struct value" 
     :at "type"   "struct type" 
     :at "fields" (mot :amap "field name" "cell"))

(mot "map value" 
     :at "type"    "map type" 
     :at "entries" (mot :amap "Go value" "cell"))

(mot "pointer value"
     :at "type"  "pointer type"
     :at "value" "cell")

;; channel buffers are FIFO queues; send/receive queues hold waiting goroutines
(mot "channel value" 
     :at "type"       "channel type" 
     :at "buffer"     (listt "Go value") 
     :at "send queue" (listt "cell") 
     :at "recv queue" (listt "cell") 
     :at "closed"     bool)

(mot "function value" 
     :at "type"      "function type" 
     :at "signature" "function signature" 
     :at "body"      "block" 
     :at "closure"   (mot :amap "variable name" "cell")) ; holds all variables accessible at the point of function declaration

(mot "function signature" 
     :at "parameters" (listt "param decl") 
     :at "variadic"   "param decl" 
     :at "results"    (uniont (listt "type") (listt "param decl")))  ; results may be named or unnamed

(mot "param decl" :at "type" "type" :at "name" "parameter name")

(mot "method value" 
     :at "type"      "method type"
     :at "signature" "method signature" 
     :at "body"      "block" 
     :at "closure"   (mot :amap "variable name" "cell"))

(mot "method signature" 
     :at "receiver"   "param decl" 
     :at "parameters" (listt "param decl") 
     :at "variadic"   "param decl" 
     :at "results"    (uniont (listt "type") (listt "param decl"))) ; holds all variables accessible at the point of method declaration

(mot "interface value" 
     :at "type"  "interface type" 
     :at "value" "Go value")


;;; ================================================
;;; Literals
;;; ================================================

(typedef "literal" (uniont "untyped constant" "numeric lit" "composite lit" "function lit" "method lit"))

(mot "numeric lit" :at "text" string)  ; translated to "untyped constant"

(typedef "composite lit" (uniont "array lit" "slice lit" "struct lit" "map lit"))

(mot "index & elem" :at "index" nat :at "value" "expression")

(mot "array lit" 
     :at "type"     "array type" 
     :at "elements" (listt "index & elem"))

(mot "slice lit" 
     :at "type"     "slice type" 
     :at "elements" (listt "index & elem"))

(mot "field & value" :at "field" "field name" :at "value" "expression")

(mot "struct lit" 
     :at "type"   "struct type" 
     :at "fields" (listt "field & value"))

(mot "key & elem" :at "key" "expression" :at "value" "expression")

(mot "map lit" 
     :at "type"     "map type" 
     :at "elements" (listt "key & elem"))

(mot "function lit" 
     :at "type"      "function type" 
     :at "signature" "function signature" 
     :at "body"      "block")

(mot "method lit" 
     :at "type"      "method type" 
     :at "signature" "method signature" 
     :at "body"      "block")


;;; ================================================
;;; Expressions
;;; ================================================

;; All expressions contain the "type" attribute, whose value is calculated during the static analysis phase.
(typedef "expression" (uniont "literal" "variable ref" "(1)" "conversion" "method expr" 
                              "field access" "method access" "index expr" "slice expr" 
                              "type assertion" "<-1" "function call" "method call"
                              "unary expression" "binary expression"))

;; represents a use of an already declared variable (not a new declaration)
(mot "variable ref" :at "name" "variable name" :at "type" "type")

;; affects evaluation order only
(mot "(1)" :at 1 "expression" :at "type" "type")

(mot "conversion" :at "type" "type" :at "value" "expression")  ; float64(2)

;; method expression returns a function with the receiver as first parameter
(mot "method expr" :at "receiver type" "type" :at "name" "method name" :at "type" "type")

(mot "field access" :at "receiver" "expression" :at "name" "field name" :at "type" "type")

(mot "method access" :at "receiver" "expression" :at "name" "method name" :at "type" "method type")

(mot "index expr" :at "indexable" "expression" :at "index" "expression" :at "type" "type")  ; indexable is an array, slice, map or string

(mot "slice expr" 
     :at "sequence" "expression"  ; is an array, slice or string
     :at "low"      "expression" 
     :at "high"     "expression" 
     :at "max"      "expression"  ; optional; omitted means cap = len(indexable)
     :at "type"     "slice type") ; сalculated during the static analysis phase

(mot "type assertion" :at "interface" "expression" :at "type" "type")  ; i.(Type); return type = target type

(mot "<-1" :at 1 "expression" :at "type" "type")  ; receive from channel

(mot "function call" :at "function" "expression" :at "arguments" (listt "expression") :at "type" "type")  ; min(1, 2)

(mot "method call" :at "receiver" "expression" :at "method" "method name" 
     :at "arguments" (listt "expression") :at "type" "type")

;; unary expressions (using digit notation for operands)
(typedef "unary expression" (uniont "+1" "-1" "^1" "!1" "*1" "&1"))
(mot "+1" :at 1 "expression" :at "type" "type")  ; unary plus (no effect)
(mot "-1" :at 1 "expression" :at "type" "type")  ; unary minus (negation)
(mot "^1" :at 1 "expression" :at "type" "type")  ; bitwise complement (^)
(mot "!1" :at 1 "expression" :at "type" "type")  ; logical not
(mot "*1" :at 1 "expression" :at "type" "type")  ; pointer dereference
(mot "&1" :at 1 "expression" :at "type" "type")  ; address of

;; binary expressions (digit notation: 1 = left operand, 2 = right operand)
(typedef "binary expression" (uniont "1||2" "1&&2" "1+2" "1-2"  "1*2" "1/2" "1%2"  
                                     "1<<2" "1>>2" "1&2" "1&^2"  "1|2" "1^2" 
                                     "1==2" "1!=2" "1<2" "1<=2" "1>2" "1>=2"))
(mot "1||2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; logical OR
(mot "1&&2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; logical AND
(mot "1+2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; addition
(mot "1-2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; subtraction
(mot "1*2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; multiplication
(mot "1/2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; division
(mot "1%2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; remainder
(mot "1<<2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; left shift
(mot "1>>2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; right shift
(mot "1&2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise AND
(mot "1&^2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise AND NOT (a &^ b = a & (^b))
(mot "1|2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise OR
(mot "1^2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise XOR
(mot "1==2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; equality
(mot "1!=2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; inequality
(mot "1<2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; less than
(mot "1<=2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; less than or equal
(mot "1>2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; greater than
(mot "1>=2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; greater than or equal


;;; ================================================
;;; Blocks
;;; ================================================

(mot "block"
	:at "statements" (listt "statement")
	
     ;; semantic attributes
     ; filled during static analysis
	:at "label positions"  (mot :amap "label name" nat)        ; statements index for each label
     :at "all variables"    (listt "variable name")             ; all variable names found in this block
     :at "decl variables"   (listt "variable name")             ; variable names that are declared in this block
     :at "variable cells"   (mot :amap "variable name" "cell")) ; cells for each variable`s memory cell before entering the block. Used to restore shadowed variables on block exit.

;;; ================================================
;;; Declarations
;;; ================================================

(typedef "declaration" (uniont "type decl" "const decl" "var decl" "function decl" "method decl"))

(mot "type decl" :at "name" "type name" :at "type" "type")
(mot "const decl" 
     :at "names"  (listt "constant name") 
     :at "types"  (listt "type")  ; optional (inferred from values)
     :at "values" (listt "expression"))
(mot "var decl" 
     :at "names"  (listt "variable name") 
     :at "types"  (listt "type")  ; optional (inferred from values)
     :at "values" (listt "expression"))
(mot "function decl" :at "name" "function name" :at "value" "function lit")
(mot "method decl"   :at "name" "method name"   :at "value" "method lit")


;;; ================================================
;;; Statements
;;; ================================================

(typedef "statement" (uniont "declaration" "label" "empty stmt" "1++" "1--" 
                             "assignment stmt" "if stmt" "switch stmt" "for stmt" 
                             "return stmt" "break stmt" "continue stmt" "goto stmt" 
                             "defer stmt" "go stmt" "1<-2" "fallthrough" "select stmt"))

(mot "label" :at "name" "label name" :at "statement" "statement")
(cot "empty stmt")  ; does nothing, used as placeholder

(mot "1++ stmt" :at 1 "expression")  ; increment
(mot "1-- stmt" :at 1 "expression")  ; decrement

;; assignment statements (digit notation)
(typedef "assignment stmt" (uniont "1=2" "1+=2" "1-=2" "1*=2" "1/=2" "1%=2" 
                                   "1<<=2" "1>>=2" "1^=2" "1|=2" "1&=2" "1&^=2"))
(mot "1=2"   :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1+=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1-=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1*=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1/=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1%=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1<<=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1>>=2" :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1^=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1|=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1&=2"  :at 1 (listt "expression") :at 2 (listt "expression"))
(mot "1&^=2" :at 1 (listt "expression") :at 2 (listt "expression"))

;; if statement
(mot "if stmt" 
     :at "init"      "statement"
     :at "condition" "expression" 
     :at "then"      "block" 
     :at "else"      (uniont "if stmt" "block"))

;; switch statement
(typedef "switch stmt" (uniont "expr switch stmt" "type switch stmt"))

(cot "default")      ; default case marker
(cot "fallthrough")  ; transfers control to the next case clause (cannot be used in type switch)

(mot "expr switch stmt" 
     :at "init"       "statement" 
     :at "controlled" "expression" 
     :at "cases"      (listt "expr case clause"))

(mot "expr case clause" 
     :at "cases"      (uniont (listt "expression") "default") 
     :at "statements" (listt "statement"))

(mot "type switch stmt" 
     :at "init"  "statement" 
     :at "name"  "variable name"  ; variable that receives the value (optional)
     :at "value" "expression"     ; expression to assert type on
     :at "cases" (listt "type case clause"))

(mot "type case clause" 
     :at "cases"      (uniont (listt "type") "default") 
     :at "statements" (listt "statement"))

;; for statement
(typedef "for stmt" (uniont "for condition" "for clause" "for range indexable" 
                            "for range map" "for range channel" "for range int"))

(mot "for condition"               ; while-like loop
     :at "condition" "expression" 
     :at "body"      "block")

(mot "for clause"                  ; traditional for loop
     :at "init"      "statement"   ; optional
     :at "condition" "expression" 
     :at "post"      "statement" 
     :at "body"      "block")

(mot "for range indexable"
     :at "index"     "variable name"
     :at "value"     "variable name"          ; optional
     :at "op"        (enumt "assign" "decl")  ; = or :=
     :at "indexable" "expression"             ; array, slice or string
     :at "body"      "block")

(mot "for range map"
     :at "key"   "variable name"
     :at "value" "variable name"          ; optional
     :at "op"    (enumt "assign" "decl")
     :at "map"   "expression"
     :at "body"  "block")

(mot "for range channel"
     :at "value"   "variable name"
     :at "op"      (enumt "assign" "decl") 
     :at "channel" "expression" 
     :at "body"    "block")

(mot "for range int"
     :at "value" "variable name" 
     :at "op"    (enumt "assign" "decl")
     :at "max"   "expression"
     :at "body"  "block")

(mot "return stmt"   :at 1 (listt "expression"))
(mot "break stmt"    :at 1 "label name")  ; optional label
(mot "continue stmt" :at 1 "label name")  ; optional label
(mot "goto stmt"     :at 1 "label name")
(mot "defer stmt"    :at 1 "expression")  ; schedules function call for later (executed when surrounding function returns)
(mot "go stmt"       :at 1 "expression")  ; spawns a goroutine (function or method call)

(mot "1<-2" :at 1 "expression" :at 2 "expression")  ; send on channel

;; select statement
(mot "select stmt" :at "cases" (listt "common clause"))

(mot "common clause" 
     :at "case"       (uniont "1<-2" "receive" "default") 
     :at "statements" (listt "statement"))

(mot "receive" 
     :at "value"   "expression"
     :at "ok"      "expression" ; variable to receive error or (nil if ok, optional)
     :at "channel" "expression"
     :at "op"      (enumt "assign" "decl") ; = for assign, := for decl
)
; ch1, ch2 := make(chan string), make(chan string)
; go func() { time.Sleep(1 * time.Second); ch1 <- "data from channel 1" }()
; go func() { time.Sleep(2 * time.Second); ch2 <- "data from channel 2" }()
; select {
; case msg1 := <-ch1: fmt.Println("Received ", msg1)
; case msg2 := <-ch2: fmt.Println("Received ", msg2)
; }

;;; ================================================
;;; Packages
;;; ================================================

(mot "file" :at "package" "identifier" :at "block" "block")
