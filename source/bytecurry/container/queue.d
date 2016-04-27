module bytecurry.container.queue;

import core.exception : RangeError;
import std.exception : enforce;
import std.range : put, isInputRange, ElementType;
import std.traits : isImplicitlyConvertible;

/**
 * A simple queue type implemented with a single linked list.
 *
 * This is a forward range, an output range and a container.
 */
struct Queue(T) {

    /**
     * Create a new queue that is pre-initialized with some elements.
     */
    this(U : T)(U[] elements...) pure @safe {
        .put(this, elements);
    }

    /**
     * Create a new queue pre-initialized with the contents of an input range.
     */
    this(Stuff)(Stuff stuff) pure @safe
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T) && !is(Stuff == T[])) {
        .put(this, stuff);
    }

    // Range operations:
    /**
     * Check if the queue is empty.
     */
    @property bool empty() pure nothrow @safe const {
        return _front is null;
    }

    /**
     * Peek at the first element of the queue.
     */
    @property inout(T) front() pure @safe inout {
        enforce!RangeError(_front);
        return _front.value;
    }

    /**
     * Moves the front out and returns it. Leaves `front` in a state
     * that does not allocate any resources.
     */
    T moveFront() pure {
        import std.algorithm : move;
        return move(_front.value);
    }

    /**
     * Pop the front element off of the queue
     */
    void popFront() pure @safe {
        enforce!RangeError(_front);
        _front = _front.next;
        if (_front is null) {
            _back = null;
        }
    }
    /// ditto
    alias removeFront = popFront;
    /// ditto
    alias stableRemoveFront = popFront;

    /**
     * Remove the front element and return it.
     */
    T removeAny() pure @safe {
        import std.algorithm : move;
        auto result = move(_front.value);
        popFront();
        return result;
    }
    /// ditto
    alias stableRemoveAny = removeAny;


    /**
     * Return a forward range over the remaining elements in the queue.
     * Popping elements off the front of the queue has no affect on this range,
     * but if additional items are pushed onto the queue before the range has been
     * emptied, those will be included in the saved range.
     */
    Range save() pure nothrow @safe {
        return Range(_front);
    }

    /// ditto
    alias opSlice = save;

    /**
     * Add a single element at the back of the queue.
     */
    void put(T element) pure nothrow @safe {
        auto node = new Node(element);
        if (_back) {
            _back.next = node;
        } else {
            _front = node;
        }
        _back = node;
    }
    /// ditto
    alias insert = put;
    /// ditto
    alias stableInsert = put;
    /// ditto
    alias linearInsert = put;
    /// ditto
    alias insertBack = put;
    /// ditto
    alias stableInsertBack = put;

    /**
     * Duplicate this queue
     */
    Queue dup() pure @safe {
        return Queue(this[]);
    }

    /**
     * Add a single element to the end of the queue.
     */
    Queue opOpAssign(string op : "~")(T element) pure nothrow @safe {
        put(element);
        return this;
    }

    /**
     * Add every element of an input range to the end of the queue.
     */
    Queue opOpAssign(string op : "~", Stuff)(Stuff stuff) pure nothrow @safe
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T)) {
        .put(this, stuff);
        return this;
    }


    /**
     * A saved view of the input side of the queue.
     *
     * popping from the front of the underlying queue has
     * no affect on this range, but adding to the end of the
     * queue will also add to the end of this range, unless it has
     * itself reached its end.
     */
    struct Range {
        private Node* node;

        @property bool empty() pure nothrow @safe const {
            return node is null;
        }

        @property inout(T) front() pure @safe inout {
            enforce!RangeError(node);
            return node.value;
        }

        void popFront() pure @safe {
            enforce!RangeError(node);
            node = node.next;
        }

        Range save() pure nothrow @safe {
            return Range(node);
        }
    }

    pure nothrow @safe invariant {
        if (_front is null) {
            assert(_back is null);
        } else {
            assert (_back !is null);
        }
    }



private:

    struct Node {
        T value;
        Node* next;
    }

    Node* _front;
    Node* _back;
}

///
unittest {
    import std.range;
    import std.algorithm : equal;

    Queue!int q;
    put(q, 1);
    put(q, 2);
    put(q, 3);
    assert(q.front == 1);
    q.popFront();
    assert(q.front == 2);
    q.popFront();
    assert(q.front == 3);
    q.popFront();
    assert(q.empty);

    q.insert(10);
    q.insert(12);
    assert(q.removeAny() == 10);
    assert(q.front == 12);

    q ~= 13;
    q ~= [20, 21, 23];

    assert(q.equal([12, 13, 20, 21, 23]));
}

///
unittest {
    import std.algorithm : equal;

    auto q = Queue!int(1,2,3,4,5);
    assert(equal(q[], [1,2,3,4,5]));
    assert(q.front == 1);
}

unittest {
    import std.range : iota;
    import std.algorithm : equal;

    auto q = Queue!int(iota(1, 5));
    assert(equal(q, [1, 2, 3, 4]));
}
