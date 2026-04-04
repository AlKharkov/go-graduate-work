(mot "array type"   :at "elem type" "type" :at "len" nat)
(mot "array value" 
     :at "type"     "array type" 
     :at "elements" (listt "Go value"))
(mot "array lit" 
     :at "type"     "array type" 
     :at "elements" (listt (mot :at "index" nat :at "value" "expression")))




(mot "slice type"   :at "elem type" "type")
(mot "slice value" 
     :at "type"     "slice type" 
     :at "array"    "array value" 
     :at "offset"   nat 
     :at "length"   nat 
     :at "capacity" nat)
(mot "slice lit" 
     :at "type"     "slice type" 
     :at "elements" (listt (mot :at "index" nat :at "value" "expression")))





(mot "struct type"  
     :at "fields" (cot :amap "field name" "type")
     :at "ordered" (listt "field name"))
(mot "struct value" 
     :at "type"   "struct type" 
     :at "fields" (cot :amap "field name" "Go value"))
(mot "struct lit" 
     :at "type"   "struct type" 
     :at "fields" (listt "field name") 
     :at "values" (listt "expression"))