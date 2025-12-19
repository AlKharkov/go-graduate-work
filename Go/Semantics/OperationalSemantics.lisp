#|
	Operational semantics for the Go language

    Last edit: 19/12/2025
|#


;;; Enviroment and Agents
(mot "env" 
    :at "agents" (listt "agent")
    :at "target construct" (uniont "expression" "statement" "external declaration" "translation unit")
)
(mot "agent"
    :at "location" (cot :amap "identifier" "location")
    :at "type name" (cot :amap "type name" "type")
    :at "value" "Go value"
)


;;; Go values
(aclosure ac "opsem::rvalue" "Go value" i :do i)


;;; Variables
(aclosure ac "opsem::rvalue" "identifier" i :agent a :do (aget (aget a "location" i) "value"))
(aclosure ac "opsem::lvalue" "identifier" i :agent a :do (aget a "location" i))


;;; Types
(aclosure ac "default type value" "base type" i :do (clear-update-eval-aclosure ac :attribute "opsem::rvalue"))
(aclosure ac "default type value" "array type" i :do ...) ; TODO...
(aclosure ac "default type value" "slice type" i :do ...) ; TODO...
(aclosure ac "default type value" "struct type" i :do ...) ; TODO...
(aclosure ac "default type value" "pointer type" i :do ...) ; TODO...
(aclosure ac "default type value" "function type" i :do ...) ; TODO...
(aclosure ac "default type value" "interface type" i :do ...) ; TODO...
(aclosure ac "default type value" "underlying type" i :do ...) ; TODO...
(aclosure ac "default type value" "map type" i :do ...) ; TODO...
(aclosure ac "default type value" "channel type" i :do ...) ; TODO...


;;; Blocks
(aclosure ac "opsem" "block" i :stage nil
    :ap i "statements" sts :do
    (update-push-aclosure ac :stage "exit block")
    (clear-update-eval-aclosure ac :stage "iteration" :av "current" 0 :av "bound" (length sts) :av "statements" sts)
)
(aclosure ac "opsem" "block" i :stage "iteration"
    :ap ac "current" p :ap "bound" n :ap ac "statements" sts :v (< p n) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (clear-update-eval-aclosure ac :instance (nth p sts))
)
(aclosure ac "opsem" "block" i :stage "exit block"
    :av i "variables" vs :do
    (clear-update-eval-aclosure ac :stage "variable handling" :av "variables" vs)
)
(aclosure ac "opsem" "block" i :stage "variable handling" :agent a
    :ap i "variables" vs :v (not (empty vs)) T :p (nth 0 vs) v :p (aget i "variable location" v) vl :do
    (update-push-aclosure ac "variables" (cdr vs))
    ; TODO
    ; Удалить a["variable location"][v]
    ; Если не nil, то:
    ;   Создать a["variable location"].add(v, vl)
)


;;; Declarations
(aclosure ac "opsem" "const decl" i :stage nil
    :ap i "specifiers" specs :do
    (update-eval-aclosure ac :stage "iteration" :av "current" 0 :av "bound" (length specs) :av "specs" specs)
)
(aclosure ac "opsem" "const decl" i :stage "iteration"
    :ap ac "current" p :ap ac "bound" n :ap ac "specs" specs :v (< p n) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (clear-update-eval-aclosure ac :instance (nth p specs))
)

(aclosure ac "opsem" "const spec" i :stage nil
    :ap i "names" ns :ap i "initializers" is :do
    (update-eval-aclosure ac :stage "iteration" :av "current" 0 :av "bound" (length ns))
)
(aclosure ac "opsem" "const spec" i :stage "iteration"
    :ap i "type" tp :ap i "names" ns :ap i "initializers" is
    :ap ac "current" p :ap ac "bound" b :v (< p b) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (update-push-aclosure ac :stage "setting value" :av "name" (nth p ns) :av "type" tp)
    (clear-update-eval-aclosure ac :instance (nth p is))
)
(aclosure ac "opsem" "const spec" i :stage "setting value"
    :ap ac "name" name :ap ac "type" tp :value v :agent a :do
    (aset a "location" name (mo "location" :av "type" tp :av "value" v))
)

(aclosure ac "opsem" "type decl" i :do ...) ; TODO

(aclosure ac "opsem" "var decl" i :stage nil
    :ap i "specifiers" specs :do
    (update-eval-aclosure ac :stage "iteration" :av "current" 0 :av "bound" (length specs) :av "specs" specs)
)
(aclosure ac "opsem" "var decl" i :stage "iteration"
    :ap ac "current" p :ap ac "bound" n :ap ac "specs" specs :v (< p n) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (clear-update-eval-aclosure ac :instance (nth p specs))
)

(aclosure ac "opsem" "var spec" i :stage nil
    :ap i "names" ns :ap i "initializers" is :do
    (update-eval-aclosure ac :stage "iteration" :av "current" 0 :av "bound names" (length ns) :av "bound inits" (length is))
)
(aclosure ac "opsem" "var spec" i :stage "iteration"
    :ap i "type" tp :ap i "names" ns :ap i "initializers" is
    :ap ac "current" p :ap ac "bound names" bn :ap ac "bound inits" bi :v (< p bn) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (update-push-aclosure ac :stage "setting value" :av "name" (nth p ns) :av "type" tp)
    (match :v (< p bi) :do
        (clear-update-eval-aclosure ac :instance (nth p is))
        :exit (clear-update-eval-aclosure ac :attribute "default type value" :instance tp)
    )
)
(aclosure ac "opsem" "var spec" i :stage "setting value"
    :ap ac "name" name :ap ac "type" tp :value v :agent a :do
    (aset a "location" name (mo "location" :av "type" tp :av "value" v))
)

(aclosure ac "opsem" "short var decl")  ; Limitations prohibit

(aclosure ac "opsem" "function decl" i :stage nil
    :ap i "name" name :ap i "signature" s :ap i "body" b :agent a :do
    (aset a "location" name (mo "location"
        :av "value" (mo "function literal" :av "signature" s :av "body" b)
        :av "type" ... ; Тип - функция(signature) - function type
        )
    )
)

(aclosure ac "opsem" "signature" i :stage nil :do
    (update-push-aclosure ac :stage "start iterating")
)
(aclosure ac "opsem" "signature" i :stage "iteration")

(aclosure ac "opsem" "method decl") ; TODO


;;; Expressions
;; Operands
(aclosure ac "opsem" "composite literal" i :do ...)  ; TODO
(aclosure ac "opsem" "keyed element" i :do i)
(aclosure ac "opsem" "function literal" i :do ...)  ; TODO
(aclosure ac "opsem" "operand[T]" i :do
    ; Создать новый объект, с подставленным типом
    ; Limitations prohibit
)
(aclosure ac "opsem::any" "(expression)" i :ap i "expression" e :do (clear-update-eval-aclosure ac "instance" e))
;primary expressions
(aclosure ac "opsem::any" "conversion" i :stage nil
    :ap i "expression" e :do
    (update-push-aclosure ac :stage "type")
    (clear-update-eval-aclosure ac :instance e)
)
(aclosure ac "opsem::any" "conversion" i :stage "type" :value e
    :ap i "type" t :do
    (update-push-aclosure ac :stage "access" :av "expression" e)
    (clear-update-eval-aclosure ac :instance t)
)
(aclosure ac "opsem::any" "conversion" i :stage "access" :value t
    :ap ac "expression" e :do
    ; Собственно приведение типа
    ; TODO
)

(aclosure "opsem::rvalue" "method expression" i ac ...)  ; TODO
;(mot "struct" :at "fields" (listt "field valued"))                   ; Куда это?
;(mot "field valued" :at "name" "identifier" :at "value" "Go value")  ; Определение экземпляра структурного объекта
(aclosure ac "opsem" "selector expression" i :stage nil :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" (aget i "expression"))
)
(aclosure ac "opsem" "selector expression" i :stage "access" :value e :ap i "selector" name :do
    ; To be continued...
)

(alcosure ac "opsem::lvalue" "index expr" i :stage nil :ap i "list" l :do
    (update-push-aclosure ac :stage "index evaluation")
    (clear-update-eval-aclosure ac :instance l)
)
(alcosure ac "opsem::lvalue" "index expr" i :stage "index evaluation" :value l :ap i "index" ind :do
    (update-push-aclosure ac :stage "access" :av "list" l)
    (clear-update-eval-aclosure ac :attribute "opsem::rvalue" :instance ind)
)
(aclosure ac "opsem::lvalue" "index expr" i :stage "access"
    :value ind :ap ac "list" l :do
    ; TODO <- array decl
)
(aclosure ac "opsem::rvalue" "index expr" i :do ...)  ; TODO
(aclosure ac "opsem" "slice expr" i :do ...)  ; TODO
(aclosure ac "opsem" "slice" i :do ...)  ; TODO
(aclosure ac "opsem::rvalue" "function call" i :do ...) ; TODO&
(aclosure ac "opsem" "argument" i :do ...) ; TODO
; unary expressions
(aclosure ac "opsem::rvalue" "+1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "+1" i :stage "access" :value e :do (+ 0 e))
(aclosure ac "opsem::rvalue" "-1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "-1" i :stage "access" :value e :do (- 0 e))
; (aclosure ac "opsem::rvalue" "^1" i :stage nil :ap i 1 e :do
;     (update-push-aclosure ac "stage" "access")
;     (clear-update-eval-aclosure ac "instance" e)
; )
; (aclosure ac "opsem::rvalue" "^1" i :stage "access" :value e :do (logxor 0 e))
(aclosure ac "opsem::rvalue" "!1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "!1" i :stage "access" :value e :do (= nil e))
(aclosure ac "opsem::lvalue" "*1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::lvalue" "*1" i :stage "access" :value e :do ...)  ; TODO after question
(aclosure ac "opsem::rvalue" "*1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "*1" i :stage "access" :value e :do ...)  ; TODO after question
(aclosure ac "opsem::rvalue" "&1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "&1" i :stage "access" :value e :do 
    ; Создаем ссылку на вычисленную переменную "e"
    ; TODO after question
)
(aclosure ac "opsem::rvalue" "<-1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "<-1" i :stage "access" :value e :do
    ; Вернуть значение из канала "e"
    ; TODO after decl channel
)
;binary expressions
(aclosure ac "opsem::rvalue" "1||2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1||2" i :stage 2 :value e1 :ap i 2 e2 :do
    (match :v e1 T :do T :exit
        (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
        (clear-update-eval-aclosure ac "instance" e2)
    )
)
(aclosure ac "opsem::rvalue" "1||2" i :stage "access" :ap ac "e1" e1 :value e2 :do (or e1 e2))
(aclosure ac "opsem::rvalue" "1&&2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1&&2" i :stage 2 :value e1 :ap i 2 e2 :do
    (match :v e1 nil :do nil :exit
        (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
        (clear-update-eval-aclosure ac "instance" e2)
    )
)
(aclosure ac "opsem::rvalue" "1&&2" i :stage "access" :value e2 :ap ac "e1" e1 :do (and e1 e2))
;;binary multiplication expressions
(aclosure ac "opsem::rvalue" "1*2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1*2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1*2" i :stage "access" :value e2 :ap ac "e1" e1 :do (* e1 e2))
(aclosure ac "opsem::rvalue" "1/2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1/2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1/2" i :stage "access" :value e2 :ap ac "e1" e1 :do (/ e1 e2))
(aclosure ac "opsem::rvalue" "1%2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1%2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1%2" i :stage "access" :value e2 :ap ac "e1" e1 :do (mod e1 e2))
(aclosure ac "opsem::rvalue" "1<<2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1<<2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1<<2" i :stage "access" :value e2 :ap ac "e1" e1 :do (ash e1 e2))
(aclosure ac "opsem::rvalue" "1>>2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1>>2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1>>2" i :stage "access" :value e2 :ap ac "e1" e1 :do (ash e1 (- e2)))
(aclosure ac "opsem::rvalue" "1&2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1&2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1&2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logand e1 e2))
(aclosure ac "opsem::rvalue" "1&^2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1&^2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1&^2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logand (logxor e1 e2) (logeqv e2 0)))
;;binary addition expressions
(aclosure ac "opsem::rvalue" "1+2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1+2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1+2" i :stage "access" :value e2 :ap ac "e1" e1 :do (+ e1 e2))
(aclosure ac "opsem::rvalue" "1-2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1-2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1-2" i :stage "access" :value e2 :ap ac "e1" e1 :do (- e1 e2))
(aclosure ac "opsem::rvalue" "1|2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1|2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1|2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logior e1 e2))
(aclosure ac "opsem::rvalue" "1^2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1^2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1^2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logxor e1 e2))
;;relation expressions
(aclosure ac "opsem::rvalue" "1==2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1==2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1==2" i :stage "access" :value e2 :ap ac "e1" e1 :do (= e1 e2))
(aclosure ac "opsem::rvalue" "1!=2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1!=2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1!=2" i :stage "access" :value e2 :ap ac "e1" e1 :do (/= e1 e2))
(aclosure ac "opsem::rvalue" "1<2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1<2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1<2" i :stage "access" :value e2 :ap ac "e1" e1 :do (< e1 e2))
(aclosure ac "opsem::rvalue" "1<=2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1<=2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1<=2" i :stage "access" :value e2 :ap ac "e1" e1 :do (<= e1 e2))
(aclosure ac "opsem::rvalue" "1>2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1>2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1>2" i :stage "access" :value e2 :ap ac "e1" e1 :do (> e1 e2))
(aclosure ac "opsem::rvalue" "1>=2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1>=2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1>=2" i :stage "access" :value e2 :ap ac "e1" e1 :do (>= e1 e2))


;;; Statements
; To be soon

