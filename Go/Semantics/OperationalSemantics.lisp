#|
	Operational semantics for the Go language

    Last edit: 17/10/2025
|#


(mot "env" 
    :at "agents" (listt "agent")
    :at "init target construct" (uniont "expression" "statement" "external declaration")
)


(mot "agent"
    :at "variable location" (cobject "variable" "location")
    :at "location value" (cobject "location" "Go value")
    :at "location type" (cobject "location" "type")
)


;;; Auxiliary generic objects
(mot "location")
(mot "Go value" (uniont "constant" "array" "slice" "struct" "function" "interface" "map" "expression" "statement"))
