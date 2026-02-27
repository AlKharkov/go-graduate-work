## Предварительно парсер обрабатывает программу:
1. Каждое значение и тип указываются явно, в том числе iota заменяется на числа и после каждой переменной явно указывается тип: (a, b int) -> (a int, b int)
1. Вложенные поля структур и интерфейсов развёртываются. Причём при конфликте имён более "явно указанные" поля имеют приоритет перед вложенными, на одном уровне вложенности - ошибка.
1. При импорте модуля происходит подстановка всех экспортируемых величин с названием модуля через точку: "math.Sin" - так выглядит название импортированной функции синуса
1. Подставляются type alias
1. short var decl -> var delc, т.е. x := 1 -> var x int = 1
1. Подставляются шаблоны и проверяется, релизуют ли типы интерфейсы


## Limitations


## The rules of good form
1. Явно указывать стадию nil, если используются другие стадии


## In order not to forget
1. Операторы имеют свой приоритет, но вычисляются значения соответсвующих выражений слева направо(пока результат не очевиден)
1. math.Pi -> (mo "variable" :av "name" "math.Pi")
1. byte alias for uint8
1. Имена функций уникальны
1. switch {} -> switch true {}
1. !TODO добавить ссылку на пример использования каналов в конце "statements"


## Questions
1. Спросить про работу :amap и как правильно писать для "block" и "const decl"
1. Правильно ли я понимаю, что лучше усложнить лексический парсер, но облегчить модель языка и операционную семантику? Например, пусть все поля в struct, map, array, slice явно имеют своё имя
1. (cot "default")

1. Можно ли тип добавить к выражениям(нет, нельзя)
1. Убрать short var decl, сделать обработку в opsem
1. signature -> type -> listt type
1. literals value -> literal
1. Method expression распистаь словами
1. Переимновать поля slice expression, selector expression; list -> arr
1. slice и slice expr лишние сущности
1. type assertion
1. function call убрать variadic argument
1. Statemtns -> операторы
1. labels


## Улучшения
1. В статье расписать ограничения


## Предложения к синтаксису
1. aclosure желательные атрибуты :attribute :type :instance
2. (aset ac :attribute :type :instance :stage :agent :value ...)


## Не понимаю, так что убираю
;;; External definitions
(mot "translation unit" :at "declarations" (listt "external declaration"))
(typedef "external declaration" (uniont "function literal" "declaration"))

env -> :at "target construct" (uniont "expression" "statement" "external declaration" "translation unit")