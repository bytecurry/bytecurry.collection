module bytecurry.container.helpers;

/**
 * Easily implement two opApply methods (one over values, and one with enumerated indices)
 * for an element type and expressions for the empty test, front element, and popping
 * the front element.
 *
 * The opApply methods are equivalent to using a range, but the expressions may be more efficient
 * than making a call to the appropriate range function (and don't require creating a range).
 */
mixin template ApplyDefinitions(E, string emptyExpr, string frontExpr, string popExpr) {
    enum popStmt = popExpr ~ ";";
    int opApply(int delegate(E) __dg) {
        int __res;
        while(!mixin(emptyExpr)) {
            __res = __dg(mixin(frontExpr));
            if (__res) {
                return __res;
            }
            mixin(popStmt);
        }
        return 0;
    }

    int opApply(int delegate(size_t, E) __dg) {
        int __res;
        size_t __i;
        while(!mixin(emptyExpr)) {
            __res = __dg(__i, mixin(frontExpr));
            if (__res) {
                return __res;
            }
            __i++;
            mixin(popStmt);
        }
        return 0;
    }
}

///
unittest {
    struct Squares {
        this(int max) {
            this.max = max;
        }

        mixin ApplyDefinitions!(int, q{curr > max}, q{curr * curr}, q{curr++});

    private:
        int curr;
        int max;
    }
    int[] mySquares;
    foreach(square; Squares(3)) {
        mySquares ~= square;
    }
    assert(mySquares == [0, 1, 4, 9]);
    int current;
    foreach(i, square; Squares(3)) {
        current = square;
        if (i == 2) {
            break;
        }
    }
    assert(current == 4);
}
