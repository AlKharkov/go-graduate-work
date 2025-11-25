#|
	Operational semantics for the Go language

    Last edit: 25/11/2025
|#


;;; Enviroment and Agents
(mot "env" 
    :at "agents" (listt "agent")
    :at "init target construct" (uniont "expression" "statement" "external declaration" "translation unit")
)
(mot "agent"
    :at "variable location" (cot :amap "variable" "location")
    :at "location value" (cot :amap "location" "Go value")
    :at "location type" (cot :amap "location" "type")
)


;;; Go values
(aclosure ac "opsem" "Go value" i :do i)


;;; Variables
(aclosure ac "opsem::rvalue" "variable" i :do (match :ap ac "agent" a :do (aget a "location value" (aget a "variable location" i))))
(aclosure ac "opsem::lvalue" "variable" i :do (aget ac "agent" "variable location" i))


;;; Types
(aclosure ac "opsem" "type" i :do i)


;;; Blocks
(aclosure ac "opsem" "block" i :stage nil  ; Буду считать указание стадии nil правилом хорошего тона для замыканий, где stage используется
    :ap i "statements" sts :do
    (update-push-aclosure ac "stage" "exit block")
    (clear-update-eval-aclosure ac :av "stage" "iteration" :av "current" 0 :av "bound" (length sts) :av "statements" sts)
)
(aclosure ac "opsem" "block" i :stage "iteration"
    :ap ac "current" p :ap "bound" n :ap ac "statements" sts :v (< p n) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (clear-update-eval-aclosure ac "instance" (nth p sts))
)
(aclosure ac "opsem" "block" i :stage "exit block"
    :av i "variables" vs :do
    (clear-update-eval-aclosure ac :av "stage" "variable handling" :av "variables" vs)
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
;TODO


;;; Expressions
;; Operands
(aclosure ac "opsem" "composite literal" i :do ...)  ; TODO
(aclosure ac "opsem" "keyed element" i :do i)
(aclosure ac "opsem" "function literal" i :do ...)  ; TODO
(aclosure ac "opsem" "operand[T]" i :do
    ; Создать новый объект, с подставленным типом
    ; TODO
)
(aclosure ac "opsem" "(expression)" i :do (clear-update-eval-aclosure ac "instance" (aget i "expression")))

(aclosure "opsem" "conversion" i ac
    (match :av ac "stage" nil :ap i "expression" e :do
        (update-push-aclosure ac "stage" "type")
        (clear-update-eval-aclosure ac "instance" e)
    )
    (match :av ac "stage" "type" :ap ac "agent" a :ap a "value" e :ap i "type" t :do
        (update-push-aclosure ac :av "stage" "access" :av "expression" e)
        (clear-update-eval-aclosure ac "instance" "type")
    )
    (match :av ac "stage" "access" :ap ac "expression" e :ap ac "agent" a :ap a "value" t
        ; Собственно приведение типа
        ; TODO
    )
)

(aclosure "opsem::rvalue" "method expression" i ac ...)  ; TODO
;(mot "struct" :at "fields" (listt "field valued"))              ; Куда это?
;(mot "field valued" :at "name" "identifier" :at "value" "Go value")  ; Определение экземпляра структурного объекта
(aclosure "opsem::lvalue" "selector expression" i ac
    (match :av ac "stage" nil :do
        (update-push-aclosure ac "stage" "access")
        (clear-update-eval-aclosure ac "instance" (aget i "expression"))
    )
    (match :av ac "stage" "access" :ap ac "agent" a :ap a "value" e :ap i "selector" name :do
        (update-push-aclosure )
        (clear-update-eval-aclosure ac :ap )
    )
)

