module bytecurry.container.cons;

struct Cons(T) {
    T front;
    Cons* rest;
}
