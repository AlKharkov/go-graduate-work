(mot "array type"   :at "elem type" "type" :at "len" nat)
(mot "array value" 
     :at "type"     "array type" 
     :at "elements" (listt "Go value"))
(mot "array lit" 
     :at "type"     "array type" 
     :at "elements" (listt "expression"))




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