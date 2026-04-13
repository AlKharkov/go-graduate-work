(mot "indexed elem" :at "index" nat :at "value" "expression")
(mot "array type"   :at "elem type" "type" :at "len" nat)
(mot "array value" 
     :at "type"     "array type" 
     :at "elements" (listt "Go value"))
(mot "array lit" 
     :at "type"     "array type" 
     :at "elements" (listt "indexed elem"))




(mot "slice type"   :at "elem type" "type")
(mot "slice value" 
     :at "type"     "slice type" 
     :at "array"    "array value" 
     :at "offset"   nat 
     :at "length"   nat 
     :at "capacity" nat)
(mot "slice lit" 
     :at "type"     "slice type" 
     :at "elements" (listt "indexed elem"))



(mot "struct type"  
     :at "fields" (cot :amap "field name" "type")
     :at "ordered" (listt "field name"))
(mot "struct value" 
     :at "type"   "struct type" 
     :at "fields" (mot :amap "field name" "Go value"))
(mot "struct lit" 
     :at "type"   "struct type" 
     :at "fields" (listt "field & value"))



(mot "map type"       :at "key type" "type" :at "elem type" "type")
(mot "map value" 
     :at "type"    "map type" 
     :at "entries" (mot :amap "Go value" "Go value"))
(mot "keyed elem" :at "key" "expression" :at "value" "expression")
(mot "map lit" 
     :at "type"     "map type" 
     :at "elements" (listt "keyed elem"))



(mot "function type" 
     :at "param types"   (listt "type") 
     :at "variadic type" "type" 
     :at "result types"  (listt "type"))
(mot "function value" 
     :at "type"      "function type" 
     :at "signature" "function signature" 
     :at "body"      "block" 
     :at "closure"   (cot :amap "variable name" "cell"))
(mot "function signature" 
     :at "parameters"     (listt "param decl") 
     :at "variadic param" "param decl" 
     :at "results"        (uniont (listt "type") (listt "param decl")))  ; results may be named or unnamed
(mot "param decl" :at "type" "type" :at "name" "parameter name")
(mot "function lit" 
     :at "type"      "function type" 
     :at "signature" "function signature" 
     :at "body"      "block")


(mot "method type" 
     :at "receiver type" "type" 
     :at "param types"   (listt "type") 
     :at "variadic type" "type" 
     :at "result types"  (listt "type"))
(mot "method value" 
     :at "type"      "method type"
     :at "signature" "method signature" 
     :at "body"      "block" 
     :at "closure"   (cot :amap "variable name" "cell"))
(mot "method signature" 
     :at "receiver"       "param decl" 
     :at "parameters"     (listt "param decl") 
     :at "variadic param" "param decl" 
     :at "results"        (listt "param decl"))
(mot "method lit" 
     :at "type"      "method type" 
     :at "signature" "method signature" 
     :at "body"      "block")
(mot "method decl"   :at "name" "method name"   :at "value" "method lit")




(mot "agent"
    :at "constant value" (mot :amap "constant name" "Go value")
    :at "variable cell"  (mot :amap "variable name" "cell")           ; The relation of names to their memory locations
    :at "function value" (mot :amap "function name" "function value")
    :at "method value"   (mot :amap "type name" (mot :amap "method name" "method value"))
    :at "type"           (mot :amap "type name" "type")               ; Types created in the program
    :at "value"          "Go value")                                  ; The last value calculated by the agent




(mot "var decl" 
     :at "names"  (listt "variable name") 
     :at "types"  (listt "type")  ; optional (inferred from values)
     :at "values" (listt "expression"))




(mot "function decl" :at "name" "function name" :at "value" "function lit")

(mot "method decl"   :at "name" "method name"   :at "value" "method lit")



(mot "block"
	:at "statements" (listt "statement")

     ;; semantic attributes
     ; filled during static analysis
	:at "label positions"  (cot :amap "label name" nat)        ; statements index for each label
     :at "all variables"    (listt "variable name")             ; all variable names found in this block
     :at "decl variables"   (listt "variable name")             ; variable names that are declared in this block
     ; filled during runtime
     :at "variable cells"   (mot :amap "variable name" "cell")  ; cells for all variables before the block (nil if not allocated)
)





;; All expressions contain the "type" attribute, whose value is calculated during the static analysis phase.
(typedef "expression" (uniont "literal" "variable ref" "(1)" "conversion" "method expr" "selector expr" 
                              "index expr" "slice expr" "type assertion" "<-1" 
                              "function call" "unary expression" "binary expression"))

;; represents a use of an already declared variable (not a new declaration)
(mot "variable ref" :at "name" "variable name" :at "type" "type")

;; affects evaluation order only
(mot "(1)" :at 1 "expression" :at "type" "type")

(mot "conversion" :at "type" "type" :at "value" "expression")  ; float64(2)

;; method expression returns a function with the receiver as first parameter
(mot "method expr" :at "receiver type" "type" :at "name" "method name" :at "type" "type")

(mot "selector expr" :at "receiver" "expression" :at "name" "identifier" :at "type" "type")  ; field or method access

(mot "index expr" :at "indexable" "expression" :at "index" "expression" :at "type" "type")  ; indexable is an array, slice, map or string

(mot "slice expr" 
     :at "slice" "expression"  ; is an array, slice or string
     :at "low"   "expression" 
     :at "high"  "expression" 
     :at "max"   "expression"  ; optional; omitted means cap = len(indexable)
     :at "type" "slice type")  ; сalculated during the static analysis phase

(mot "type assertion" :at "interface" "expression" :at "type" "type")  ; i.(Type); return type = target type

(mot "<-1" :at 1 "expression" :at "type" "type")  ; receive from channel

(mot "function call" :at "function" "expression" :at "arguments" (listt "expression") :at "type" "type")  ; min(1, 2)

;; unary expressions (using digit notation for operands)
(typedef "unary expression" (uniont "+1" "-1" "^1" "!1" "*1" "&1"))
(mot "+1" :at 1 "expression" :at "type" "type")  ; unary plus (no effect)
(mot "-1" :at 1 "expression" :at "type" "type")  ; unary minus (negation)
(mot "^1" :at 1 "expression" :at "type" "type")  ; bitwise complement (^)
(mot "!1" :at 1 "expression" :at "type" "type")  ; logical not
(mot "*1" :at 1 "expression" :at "type" "type")  ; pointer dereference
(mot "&1" :at 1 "expression" :at "type" "type")  ; address of
 
;; binary expressions (digit notation: 1 = left operand, 2 = right operand)
(typedef "binary expression" (uniont "1||2" "1&&2" "1*2" "1/2" "1%2" "1<<2" "1>>2" 
                                     "1&2" "1&^2" "1+2" "1-2" "1|2" "1^2" "1==2" 
                                     "1!=2" "1<2" "1<=2" "1>2" "1>=2"))
(mot "1||2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; logical OR
(mot "1&&2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; logical AND
(mot "1*2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; multiplication
(mot "1/2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; division
(mot "1%2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; remainder (integers only)
(mot "1<<2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; left shift
(mot "1>>2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; right shift
(mot "1&2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise AND
(mot "1&^2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise AND NOT (a &^ b = a & (^b))
(mot "1+2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; addition
(mot "1-2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; subtraction
(mot "1|2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise OR
(mot "1^2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; bitwise XOR
(mot "1==2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; equality
(mot "1!=2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; inequality
(mot "1<2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; less than
(mot "1<=2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; less than or equal
(mot "1>2"  :at 1 "expression" :at 2 "expression" :at "type" "type")  ; greater than
(mot "1>=2" :at 1 "expression" :at 2 "expression" :at "type" "type")  ; greater than or equal



;;;;;;;;;;;;;; Пока что лишнее

(aclosure ac :attribute "opsem::rvalue" :type "identifier" :instance i :do 
    (match :v (aget a "constant value" i) nil :exit (aget a "constant value" i) 
           :v (aget a "variable cell"  i) nil :exit (aget (aget a "variable cell" i) "value") 
           :v (aget a "function value" i) nil :exit (aget a "function value" i) 
           :v (aget a "method value"   i) nil :exit (aget a "method value" i)))
