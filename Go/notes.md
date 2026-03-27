## На этапе операционной семантики обрабатывается программа по следующим правилам:
1. При перечислении констант, переменных, параметров функций типы явно подставляются: (a, b int) -> (a int, b int)
1. Вычисляются значения по умолчанию для констант, переменных объявляемых без значения, а только с типом


## Limitations
1. Без шаблонов
1. Поля в одной структуре должны быть уникальными, т.е. если в исходной структуре есть поле, то его имя не совпадает ни с каким именем исходной структуры или любой другой её подструктуры


## The rules of good form
1. Явно указывать стадию nil, если используются другие стадии


## In order not to forget
1. Операторы имеют свой приоритет, но вычисляются значения соответсвующих выражений слева направо(пока результат не очевиден)
1. byte alias for uint8
1. Имена функций уникальны
1. switch {} -> switch true {}
1. !TODO добавить ссылку на пример использования каналов в конце "statements"
1. Значением литералов не может быть только "literal" т.к. не поддерживает указатели
1. Type assertion может вызвать punic
1. Подставляется значение из строки выше только в блоке const()
1. opsem: "multi" -> (listt "single")
1. "default type by value" :type "signature" |-> выполняется только после type substitution иначе нужно обрабатывать multi param decl



## Questions
- Как удалить элемент из :amap?
- Нужно ли удалять iota из переменных, или можно и оставить?
- :p 10 x будет ли эквивалентно (setq x 10)?


## Улучшения



## Предложения к синтаксису
1. aclosure желательные атрибуты :attribute :type :instance
2. (aset ac :attribute :type :instance :stage :agent :value ...)


## Не понимаю, так что убираю
;;; External definitions
(mot "translation unit" :at "declarations" (listt "external declaration"))
(typedef "external declaration" (uniont "function literal" "declaration"))

env -> :at "target construct" (uniont "expression" "statement" "external declaration" "translation unit")

## Пока что не нужно
;;; Packages
(mot "import package" :amap "package name" "path")
(typedef "path" (uniont string))  ; import m "lib/math"