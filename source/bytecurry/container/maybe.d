module bytecurry.container.maybe;

import core.exception : RangeError;
import std.exception : assertThrown;

private struct Range(T) {
    this(Maybe!T m) pure @safe @nogc nothrow {
        this.m = m;
    }

    this(T content, bool empty) pure @safe @nogc nothrow {
        this.m = Maybe!T(content, empty);
    }

    @property bool empty() pure @safe @nogc nothrow const{
        return m.empty;
    }

    @property inout(T) front() pure @safe inout {
        return m.get;
    }

    void popFront() pure @nogc @safe {
        m._empty = true;
    }

    alias back = front;
    alias popBack = popFront;

    inout(Range) save() pure nothrow @nogc @safe inout {
        return this;
    }

    @property size_t length() pure nothrow @safe @nogc const {
        return m.length;
    }

    inout(T) opIndex(size_t n) pure @safe inout {
        return m[n];
    }

private:
    Maybe!T m;
}

/**
 * A container representing a value that may or may not exist. Similar to Maybe in Haskell, or Option in Scala.
 * In some ways it is similar to a `Nullable`, but unlike a nullable it acts like a container, and can be "iterated" over.
 *
 * You can think of a Maybe as a container that contains either zero or one elements.
 */
struct Maybe(T) {

    /**
     * Initialize the Maybe with a non-empty value (A just value).
     */
    this(T content) pure nothrow @safe @nogc {
        this.content = content;
        this._empty = false;
    }

    private this(T content, bool empty) pure nothrow @safe @nogc {
        this.content = content;
        this._empty = empty;
    }

    /**
     * If true the Maybe doesn't have any content, and get/front should not be called.
     */
    @property bool empty() pure nothrow @safe @nogc const {
        return _empty;
    }

    /**
     * Get the value contained in the Maybe. If the Maybe is empty, an exception is thrown.
     * Calling this function should be avoided.
     */
    @property inout(T) get() pure @safe inout {
        if (_empty) {
            throw new RangeError();
        }
        return content;
    }
    /// ditto
    alias front = get;

    /**
     * Get the current value of the Maybe if non-empty, otherwise return
     * `otherwise`.
     */
    auto getOrElse(U)(lazy U otherwise) pure @safe @nogc inout {
        if (_empty) {
            return otherwise;
        } else {
            return content;
        }
    }


    /**
     * Return a random access range of the maybe. If the Maybe is empty, it is an empty range, and
     * if it is non-empty it is a range containing a single element.
     */
    Range!T opSlice() pure nothrow @safe @nogc {
        return Range!T(this);
    }

    /// ditto
    Range!(const T) opSlice() pure nothrow @safe @nogc const {
        return typeof(return)(content, _empty);
    }

    /**
     * Get the length of the container.
     * This always returns either 0 or 1 and is provided for compatibility with other containers.
     */
    @property size_t length() pure nothrow @safe @nogc const {
        if(_empty) {
            return 0;
        } else {
            return 1;
        }
    }

    /**
     * Index into the container. The only valid index is 0, and then only if the Maybe is non-empty.
     * Provided for compatibility with other containers.
     */
    inout(T) opIndex(size_t n) pure @safe inout {
        if (n == 0 && !_empty) {
            return content;
        } else {
            throw new RangeError();
        }
    }

    /**
     * Iterate through the maybe. The delegate is called with
     * the content of the Maybe once if the Maybe is non-empty.
     */
    int opApply(scope int delegate(ref T) dg) {
        if(!_empty) {
            return dg(content);
        } else {
            return 0;
        }
    }

    /// ditto
    int opApply(scope int delegate(const T) dg) const {
        if(!_empty) {
            return dg(content);
        } else {
            return 0;
        }
    }

    /**
     * If this Maybe is empty, return `nothing!U`.
     * If this Maybe isn't empty return a new non-empty Maybe
     * containing the result of calling f with the content.
     */
    Maybe!U map(U)(scope U delegate(const T) f) const {
        if(_empty) {
            return nothing!U;
        } else {
            return just(f(content));
        }
    }

    /**
     * If this Maybe is empty, return `nothing!U`.
     * If this Maybe isn't empty return the result of calling `f` with
     * the content of this Maybe.
     */
    Maybe!U flatMap(U)(scope Maybe!U delegate(const T) f) const {
        if (_empty) {
            return nothing!U;
        } else {
            return f(content);
        }
    }

    static if(is(T U: Maybe!U)) {
        /**
         * Flatten a Maybe of a Maybe.
         */
        @property Maybe!U flatten() pure nothrow @safe @nogc const {
            if (_empty) {
                return nothing!U;
            } else {
                return content;
            }
        }
    }



private:
    T content;
    bool _empty = true;
}

///
unittest {
    foreach (int x; nothing!int) {
        assert(false);
    }
    int flag = 0;
    foreach (int x; just(5)) {
        flag = x;
    }
    assert(flag == 5);
}

///
unittest {
    assertThrown!RangeError(nothing!int.get);
    assertThrown!RangeError(nothing!int[0]);
    assert(just(5).get == 5);
    assert(just(5)[0] == 5);
    assertThrown!RangeError(just(5)[1]);

    assert(just(5).length == 1);
    assert(nothing!int.length == 0);
}

///
unittest {
    auto r1 = just(5)[];
    auto r2 = nothing!int[];
    assert(r1.front == 5);
    assert(r1.back == 5);
    assert(r2.empty);
    assert(r1.length == 1);
    assert(r2.length == 0);

    auto old = r1.save();
    r1.popFront();
    assert(r1.empty);
    assert(!old.empty);
    assert(old.front == 5);
    old.popBack();
    assert(old.empty);
}

///
unittest {
    import std.stdio;
    assert(just(5).map(x => x + 1).get == 6);
    assert(nothing!int.map(x => x + 1).empty);

    Maybe!int f(const int x) {
        if (x == 0) {
            return nothing!int;
        } else {
            return just(x / 2);
        }
    }

    assert(just(5).flatMap(&f).get == 2);
    assert(just(0).flatMap(&f).empty);
    assert(nothing!int.flatMap(&f).empty);

    assert(just(just(5)).flatten == just(5));
}

/**
 * Create an Empty Maybe of type T
 */
template nothing(T) {
    enum nothing = Maybe!T();
}

///
unittest {
    assert(nothing!int.empty);
    assert(nothing!(int[]).empty);
    assert(nothing!string.empty);
    class A {}
    assert(nothing!A.empty);
}

/**
 * Create a non-empty Maybe containing the content `v`.
 */
Maybe!T just(T)(T v) pure nothrow @safe @nogc {
    return Maybe!T(v);
}

///
unittest {
    assert(just(5).get == 5);
    assert(just("hello").get == "hello");

    class A {}
    auto a = new A();
    assert(just(a).get == a);
}

/**
 * Create a Maybe object that is empty if `content` is null.
 * Converts Nullable or NullableRef to a Maybe.
 */
auto maybe(T)(T content) pure nothrow @safe @nogc
    if (is(typeof(content.isNull) == bool) && is(typeof(content.get)))
{
    if (content.isNull) {
        return nothing!(typeof(content.get));
    } else {
        return just(content.get);
    }
}

/// ditto
Maybe!T maybe(T)(T content) pure nothrow @safe @nogc
    if (!is(typeof(content.isNull) == bool))
{
    if (content is null) {
        return nothing!T;
    } else {
        return just(content);
    }
}

///
unittest {
    import std.typecons;
    Nullable!int n;
    Maybe!int m = maybe(n);
    assert(m.empty);
    n = 5;
    m = maybe(n);
    assert(!m.empty);
    assert(m.get == 5);

    Nullable!(int, 0) n2 = 5;
    m = maybe(n2);
    assert(!m.empty);
    assert(m.get == 5);
    n2 = 0;
    m = maybe(n2);
    assert(m.empty);

    NullableRef!int r;
    m = maybe(r);
    assert(m.empty);
    r.bind(new int(42));
    m = maybe(r);
    assert(!m.empty);
    assert(m.get == 42);
}

///
unittest {
    class A {}
    A a;
    int* p;
    int[] arr;
    int[string] aa;

    assert(maybe(a).empty);
    assert(maybe(p).empty);
    assert(maybe(arr).empty);
    assert(maybe(aa).empty);
}
