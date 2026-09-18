package main

func main() {
	// for clause (init; cond; post)
	for i := 0; i < 10; i++ {
		_ = i
	}

	// for condition (while)
	n := 0
	for n < 5 {
		n++
	}

	// for без условия (бесконечный)
	for {
		n++
		if n > 10 {
			break
		}
	}

	// for range по срезу
	slice := []int{1, 2, 3}
	for i, v := range slice {
		_, _ = i, v
	}

	// for range без value
	for i := range slice {
		_ = i
	}

	// for range по карте
	m := map[string]int{"a": 1, "b": 2}
	for k, v := range m {
		_, _ = k, v
	}

	// for range по строке
	s := "hello"
	for i, r := range s {
		_, _ = i, r
	}

	// for range по каналу
	ch := make(chan int, 3)
	ch <- 1
	ch <- 2
	close(ch)
	for v := range ch {
		_ = v
	}

	// for range по int (Go 1.22+)
	for i := range 5 {
		_ = i
	}
}
