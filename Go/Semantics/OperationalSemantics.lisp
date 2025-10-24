#|
	Operational semantics for the Go language

    Last edit: 24/10/2025
|#


;;; Enviroment and Agents
(mot "env" 
    :at "agents" (listt "agent")
    :at "init target construct" (uniont (listt "external declaration"))
    ;:at "init target construct" (uniont "expression" "statement" "external declaration")  ; Зачем это?
)

(mot "agent"
    :at "variable location" (cot :amap "variable" "location")
    :at "location value" (cot :amap "location" "Go value")
    :at "location type" (cot :amap "location" "type")
)


;;; Go values
(aclosure "opsem" "Go value" i ac i)


;;; Variables
(aclosure "opsem" "variable" i ac (match :ap ac "agent" a :do (aget a "location value" (aget a "location" i))))  ; Что после :do происходит?


;;; Expressions
