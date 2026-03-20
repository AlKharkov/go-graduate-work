## Предварительно парсер обрабатывает программу:
1. Подставляются значения констант вместо их имён
1. Каждое значение и тип указываются явно, в том числе с каждой переменной явно указывается тип: (a, b int) -> (a int, b int)
1. Вложенные поля структур и интерфейсов развёртываются. Причём при конфликте имён более "явно указанные" поля имеют приоритет перед вложенными, на одном уровне вложенности - ошибка.
1. При импорте модуля происходит подстановка всех экспортируемых величин с названием модуля через точку. Например, "math.Sin" - так выглядит название импортированной функции синуса; P.S. Если убирать, то добавить функционал в Selector expression
1. Подставляются type alias
1. short var decl -> var delc, т.е. x := 1 -> var x int = 1
1. Подставляются шаблоны и проверяется, релизуют ли типы интерфейсы


## Limitations
1. Без шаблонов


## The rules of good form
1. Явно указывать стадию nil, если используются другие стадии


## In order not to forget
1. Операторы имеют свой приоритет, но вычисляются значения соответсвующих выражений слева направо(пока результат не очевиден)
1. math.Pi -> (mo "variable" :av "name" "math.Pi")
1. byte alias for uint8
1. Имена функций уникальны
1. switch {} -> switch true {}
1. !TODO добавить ссылку на пример использования каналов в конце "statements"
1. Значением литералов не может быть только "literal" т.к. не поддерживает указатели
1. Type assertion может вызвать punic
- Проверить "identifier" на то, не забыл ли поменять на "variable name" etc

## Questions
1. Спросить про работу :amap и как правильно писать для "block" и "const decl"
1. (cot "default")

- Method expression распистаь словами


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

## Пока что не нужно
;;; Packages
(mot "import package" :amap "package name" "path")
(typedef "path" (uniont string))  ; import m "lib/math"