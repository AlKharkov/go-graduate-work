#|
	Operational semantics for the Go language

    Last edit: 26/02/2026
|#


;;; Enviroment and Agents
(mot "env" 
    :at "agents" (listt "agent")
)
(mot "agent"
    :at "location" (cot :amap "identifier" "location")  ; The relation of names to their memory locations
    :at "type name" (cot :amap "type name" "type")      ; Types created in the program
    :at "value" "Go value"                              ; The last value calculated by the agent
)


;;; Go values
(aclosure ac "opsem::rvalue" "Go value" i :do i)


;;; Variables
(aclosure ac "opsem::rvalue" "identifier" i :agent a :do (aget (aget a "location" i) "value"))
(aclosure ac "opsem::lvalue" "identifier" i :agent a :do (aget a "location" i))


;;; Types
(aclosure ac "default type value" "boolean type" i :do nil)
(aclosure ac "default type value" "int type" i :do 0)
(aclosure ac "default type value" "float type" i :do 0.0)
(aclosure ac "default type value" "complex type" i :do (complex 0 0))
(aclosure ac "default type value" "rune type" i :do nil)
(aclosure ac "default type value" "string type" i :do "")
(aclosure ac "default type value" "array type" i :stage nil
    :ap i "len" n :ap i "element type" et :do 
    (update-push-aclosure ac :stage "start creating list")
    (clear-update-eval-aclosure ac :instace et)  ; Вычисляем значение по умолчанию для элемента этого массива
)
(aclosure ac "default type value" "array type" i :stage "start creating list" 
    :ap i "len" n :value ev :do 
    (update-push-aclosure ac :stage "exit array type")
    (clear-update-eval-aclosure ac :stage "creating list" :av "current" (list) :av "left" n :av "element value" ev)  ; Создать массив из n элементов ev
)
(aclosure ac "default type value" "array type" i :stage "creating list"
    :ap ac "current" lst :ap ac "left" k :ap ac "element value" ev :do 
    (match (> k 0) T :do 
        (update-eval-aclosure ac :av "current" (cons ev lst) :av "left" (- k 1))  ; Добавить 1 элемент к массиву
        :exit lst  ; Если список готов, то вернуть его
    )
)
(aclosure ac "default type value" "array type" i :stage "exit array type" 
    :value lst :do (mo "array lit" :av "type" i :value lst)
)
(aclosure ac "default type value" "slice type" i :do (mo "slice lit" :av "type" i :av "value" (list)))
(aclosure ac "default type value" "struct type" i :stage nil 
    :ap i "fields" fs :p (attributes fs) ns :p fv (co :amap "identifier" "Go value") :do
    (update-push-aclosure ac :stage "exit struct type")
    (match :v (> (length ns) 0) :do
        (update-push-aclosure ac :stage "adding default value" :av "current" 0 :av "field values" fv)
        (clear-update-eval-aclosure ac :instance (aget fs (car ns)))
    )
)
(aclosure ac "default type value" "struct type" i :stage "adding default value" 
    :ap i "fields" fs :p (attributes fs) ns :ap ac "current" p :ap ac "field values" fv :v (< p (length ns)) T :value dv :do 
    (aset fv (nth p ns) dv)  ; Добавляем значение нового поля
    (update-eval-aclosure ac :av "field values" fv :av "current" (+ p 1))  ; Шаг итерации
    (match :v (< (+ p 1) (length ns)) T :do 
        (clear-update-eval-aclosure ac :instance (aget fs (nth (+ p 1) ns)))  ; Вычисляем значение по умолчанию для следующего поля
        :exit fv  ; Если все поля готовы, то вернуть
    )
)
(aclosure ac "default type value" "struct type" i :stage "exit array type" 
    :value fv :do (mo "struct lit" :av "type" i :av "value" fv)
)
(aclosure ac "default type value" "pointer type" i :do nil)
(aclosure ac "default type value" "function type" i :stage nil :do 
    (update-push-aclosure ac :stage "exit function type")
    (clear-update-eval-aclosure ac :type "body")  ; Для независимой реализации значения по умолчанию блока
)
(aclosure ac "default type value" "function type" i :stage "exit function type" :value bd :do
    (clear-update-eval-aclosure ac (mo "function lit" :at "signature" (aget i "signature") :at "body" bd))
)
(aclosure ac "default type value" "interface type" i :do i)  ; Интерфейс сам по себе является как классом, так и единственным его представителем
(aclosure ac "default type value" "map type" i :do (mo "map lit" :av "type" i :av "value" (cot :amap "identifier" "Go value")))
(aclosure ac "default type value" "channel type" i :do nil)

(aclosure ac "default type value" "body" :do 
    (mo "body" :av "statements" (list) :av "variable location" (cot :amap "identifier" "location") :av "label position" (cot :amap "label" nat))
)


;;; Blocks
(aclosure ac "opsem" "block" i :stage nil
    :ap i "statements" sts :ap i "variable location" vl :p (attributes vl) ns :do
    (update-push-aclosure ac :stage "variable handling" :av "current" 0 :av "bound" (length ns) :av "variable location" vl :av "names" ns)
    (clear-update-eval-aclosure ac :stage "evaluating statement" :av "current" 0 :av "bound" (length sts) :av "statements" sts)
)
(aclosure ac "opsem" "block" i :stage "evaluating statement"
    :ap ac "current" p :ap ac "bound" n :ap ac "statements" sts :v (< p n) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (clear-update-eval-aclosure ac :instance (nth p sts))
)
(aclosure ac "opsem" "block" i :stage "variable handling" :agent a
    :ap ac "current" p :ap ac "bound" n :ap ac "variable location" vl :ap "names" ns :v (< p n) T :do 
    (aset a "location" (nth p ns) (nth p vl))  ; Возвращаем прежнее значение переменной
    (clear-update-eval-aclosure ac "current" (+ p 1))
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
        :av "value" (mo "function literal" :av "signature" s :av "body" b) ; signature -> "parameters"
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
(aclosure ac "opsem" "function literal" i :do ...)  ; TODO...
(aclosure ac "opsem" "operand[T]" i :do
    ; Создать новый объект, с подставленным типом
    ; Limitations prohibit - предварительно вычисляем
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

