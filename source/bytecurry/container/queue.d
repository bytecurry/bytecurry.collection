module bytecurry.container.queue;

import core.exception : RangeError;
import std.algorithm : move;
import std.container.dlist : DList;
import std.range;
import std.traits : isImplicitlyConvertible;

/**
 * Interface for a FIFO queue container.
 * It is a ForwardRange, an OutputRange, and a container.
 *
 * Elements are added to the back and pulled from the front.
 */
interface Queue(E): ForwardRange!E, OutputRange!E {

    /**
     * Alias for popFront.
     * A queue should support stably removing the front
     * element.
     */
    alias removeFront = popFront;
    /// ditto
    alias stableRemoveFront = popFront;

    /**
     * Alias for save. Returns a range of the queue.
     */
    alias opSlice = save;

    /**
     * `insert` is an alias for put, to store an element in the end of the
     * queue.
     */
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
     * Remove the front element and return it.
     * This function should be stable for ranges.
     */
    E removeAny();
    /// ditto
    alias stableRemoveAny = removeAny;

    /**
     * Clear all elements from the queue.
     */
    void clear();

    /**
     * Syntactic sugar for appending one or more elements.
     */
    final auto opOpAssign(string op : "~")(E element) {
        put(element);
        return this;
    }

    /// ditto
    final auto opOpAssign(string op : "~", Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, E)) {
        foreach (el; stuff) {
            put(el);
        }
        return this;
    }
}

/**
 * A simple queue type implemented with a single linked list.
 *
 */
class SListQueue(E): Queue!E {

    /**
     * Create a new queue that is pre-initialized with some elements.
     */
    this(U : E)(U[] elements...) {
        put(elements);
    }

    /**
     * Create a new queue pre-initialized with the contents of an input range.
     */
    this(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, E) && !is(Stuff == E[])) {
        put(stuff);
    }

    // Range operations:
    /**
     * Check if the queue is empty.
     *
     * Complexity: $(BIGOH 1)
     */
    override bool empty() @property pure @safe nothrow const {
        return  _front is null;
    }

    /**
     * Peek at the first element of the queue.
     *
     * Complexity: $(BIGOH 1)
     */
    override E front() @property {
        assert(!empty, "Queue.front: Queue is empty");
        return _front.value;
    }

    /**
     * Moves the front out and returns it. Leaves `front` in a state
     * that does not allocate any resources.
     *
     * Complexity: $(BIGOH 1)
     */
    override E moveFront() {
        return move(_front.value);
    }

    /**
     * Pop the front element off of the queue
     *
     * Complexity: $(BIGOH 1)
     */
    override void popFront() pure @safe {
        assert(!empty, "Queue.popFront: Queue is empty");
        _front = _front.next;
        if (_front is null) {
            _back = null;
        }
    }

    override E removeAny() pure @safe {
        auto result = move(_front.value);
        popFront();
        return result;
    }

    /**
     * Return a forward range over the remaining elements in the queue.
     * Popping elements off the front of the queue has no affect on this range,
     * but if additional items are pushed onto the queue before the range has been
     * emptied, those will be included in the saved range.
     */
    override Range save() nothrow {
        if (empty) {
            return new Range(null);
        } else {
            return new Range(_front);
        }
    }

    /**
     * Iterate over the rest of the queue. Note that this consumes
     * the queue.
     */
    override int opApply(int delegate(E) dg) {
        int res;
        while (_front) {
            res = dg(_front.value);
            if (res) {
                return res;
            }
            _front = _front.next;
        }
        return 0;
    }
    /// ditto
    override int opApply(int delegate(size_t, E) dg) {
        int res;
        size_t i;
        while (_front) {
            res = dg(i, _front.value);
            if (res) {
                return res;
            }
            _front = _front.next;
            i++;
        }
        return 0;
    }

    /**
     * Add an element or a range of elements at the back of the queue.
     */
    override void put(E element) pure nothrow @safe {
        auto node = new Node(element);
        if (_back) {
            _back.next = node;
        } else {
            _front = node;
        }
        _back = node;
    }

    /**
     * Optimization to insert multiple elements at a time.
     */
    size_t put(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, E)) {
        size_t result;
        Node* node, firstNode;
        foreach (item; stuff) {
            auto newNode = new Node(item);
            (node ? node.next : firstNode) = newNode;
            node = newNode;
            result++;
        }
        if (_back) {
            _back.next = firstNode;
        } else {
            _front = firstNode;
        }
        _back = node;
        return result;
    }

    /**
     * Duplicate this queue
     */
    SListQueue dup() {
        return new SListQueue(this.save());
    }

    /// ditto
    override bool opEquals(Object o) pure @safe const {
        SListQueue rhs = cast(SListQueue) o;
        if (rhs is null) {
            return false;
        }
        if (_front is rhs._front && _back is rhs._back) {
            return true;
        } else {
            // pointers are different, we need to iterate through the nodes;
            const(Node)* n1 = _front, n2 = rhs._front;
            for (;; n1 = n1.next, n2 = n2.next) {
                if (n1 is null) {
                    return n2 is null;
                }
                if (!n2 || n1.value != n2.value) {
                    return false;
                }
            }
        }
    }

    /**
     * Clear the queue
     */
    override void clear() pure nothrow @safe {
        _front = null;
        _back = null;
    }


    /**
     * A saved view of the input side of the queue.
     *
     * popping from the front of the underlying queue has
     * no affect on this range, but adding to the end of the
     * queue will also add to the end of this range, unless it has
     * itself reached its end.
     */
    class Range : ForwardRange!E {
        private Node* node;

        this(Node* node) {
            this.node = node;
        }

        @property bool empty() pure nothrow @safe const {
            return node is null;
        }

        @property E front() pure @safe {
            assert(node, "Queue.Range.front: Range is empty");
            return node.value;
        }

        void popFront() pure @safe {
            assert(node, "Queue.Range.popFront: Range is empty");
            node = node.next;
        }

        E moveFront() pure @safe {
            assert(node, "Queue.Range.moveFront: Range is empty");
            return move(node.value);
        }

        Range save() pure nothrow @safe {
            return new Range(node);
        }

        int opApply(int delegate(E) dg) {
            int res;
            while (node) {
                res = dg(node.value);
                if (res) {
                    return res;
                }
                node = node.next;
            }
            return 0;
        }

        int opApply(int delegate(size_t, E) dg) {
            int res;
            size_t i;
            while (node) {
                res = dg(i, node.value);
                if (res) {
                    return res;
                }
                node = node.next;
                i++;
            }
            return 0;
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
        E value;
        Node* next;
    }

    Node* _front;
    Node* _back;
}

/**
 * Create a new queue that is pre-initialized with some elements.
 */
Queue!E queue(E)(E[] elements...) pure @safe {
    return new SListQueue!E(elements);
}


///
unittest {
    import std.range;
    import std.algorithm : equal;

    Queue!int q = queue!int();
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

    auto q = queue(1,2,3,4,5);
    assert(equal(q[], [1,2,3,4,5]));
    assert(q.front == 1);
}

unittest {
    import std.range : iota;
    import std.algorithm : equal;

    auto q = new SListQueue!int(iota(1, 5));
    assert(equal(q, [1, 2, 3, 4]));
}

// test reference semantics
unittest {
    import std.algorithm : equal;

    auto q1 = queue(10, 20, 30);
    auto q2 = q1;
    q2.popFront();
    assert(q1.front == 20);
    q1.insert(67);
    assert(equal(q2, [20, 30, 67]));
}

// test equality
unittest {
    Queue!int q1 = queue!int();
    Queue!int q2 = queue!int();

    assert(q1 == q1);
    assert(q1 == q2);
    q1.put(1);
    assert(q1 != q2);
    q2.put(1);
    assert(q1 == q2);

    Queue!int q3 = q1;
    assert(q1 == q3);

    q1.popFront();
    assert(q1 == q3);
    assert(q1 != q2);
    q2.popFront();
    assert(q1 == q2);

    put(q1, [1,2,3,4,5]);
    put(q2, [1,2,3,4]);
    assert(q1 != q2);
    assert(q2 != q1);
    q2.put(5);
    assert(q1 == q2);
}

/**
 * A Queue that wraps an input range that is also an output range.
 */
template RangeQueue(R) if (isForwardRange!R && isOutputRange!(R, ElementType!R)) {
    private alias E = ElementType!R;
    static if (is(R: Queue!E)) {
        alias RangeQueue = R;
    } else {
        class RangeQueue : Queue!E {
            protected R _range;

            this(R range) {
                _range = range;
            }

            static if(is(typeof(R.init))) {
                this() {
                    _range = R.init;
                }
            }

            // InputRange functions:

            bool empty() @property {
                return _range.empty;
            }
            E front() @property {
                return _range.front;
            }
            void popFront() {
                _range.popFront();
            }
            E moveFront() @property {
                return .moveFront(_range);
            }

            int opApply(int delegate(E) dg) {
                int res;
                for (auto r = _range; !r.empty; r.popFront()) {
                    res = dg(r.front);
                    if (res != 0) {
                        return res;
                    }
                }
                return res;
            }
            int opApply(int delegate(size_t, E) dg) {
                int res;
                size_t i = 0;
                for (auto r= _range; !r.empty; r.popFront(), i++) {
                    res = dg(i, r.front);
                    if (res != 0) {
                        return res;
                    }
                }
                return res;
            }

            //Forward Range function
            static if (is(R: ForwardRange!E)) {
                ForwardRange!E save() {
                    return _range.save();
                }
            } else {
                ForwardRange!E save() {
                    return inputRangeObject(_range.save());
                }
            }

            // Output Range functions
            void put(E element) {
                .put(_range, element);
            }

            //Other:

            E removeAny() {
                auto result = .moveFront(_range);
                _range.popFront();
                return result;
            }

            static if (is(typeof(_range.clear()))) {
                void clear() {
                    _range.clear();
                }
            } else {
                void clear() {
                    _range = R.init;
                }
            }

        }
    }
}

/**
 * Create a Queue wrapper around a Forward Range that is also an input range.
 */
auto rangeQueue(R)(R range) {
    return new RangeQueue!R(range);
}

/**
 * A queue backed by a dynamic array.
 * Note that this may reallocate the entire array
 * periodically.
 */
class ArrayQueue(E): RangeQueue!(E[]) {
    override void put(E element) {
        _range ~= element;
    }
}

///
unittest {
    auto q = new ArrayQueue!int();
    q.put(5);
    q.put(6);
    assert(q.front == 5);
    q.popFront();
    assert(q.front == 6);
    q.popFront();
    assert(q.empty);
}

private template isQueueLike(C) {
    enum isQueueLike = is(typeof((C c) {
                if (!c.empty) {
                    c.removeFront();
                }
                auto x = c.front;
                c.insertBack(x);
            })) && isForwardRange!(typeof(C.init.opSlice()));
}

/**
 * A Queue backed by a container with the following characteristics:
 * The following container methods are defined: `empty`, `front`, `removeFront`, `insertBack`,
 * and `opSlice` is defined and returns a forward range.
 */
template ContainerQueue(C) if (isQueueLike!C) {
    private alias E = ElementType!C;
    static if (is(C: Queue!E)) {
        alias ContainerQueue = C;
    } else {
        class ContainerQueue : Queue!E {
            protected C _container;

            this(C container = C.init) {
                _container = container;
            }

            override bool empty() @property {
                return _container.empty;
            }

            override E front() @property {
                return _container.front;
            }

            override void popFront() {
                _container.removeFront();
            }

            override E moveFront() {
                return .moveFront(_container);
            }

            override ForwardRange!E save() {
                return inputRangeObject(_container.opSlice());
            }

            int opApply(int delegate(E) dg) {
                int res;
                for(auto c = _container; !c.empty; c.removeFront()) {
                    res = dg(c.front);
                    if (res) {
                        return res;
                    }
                }
                return 0;
            }
            int opApply(int delegate(size_t, E) dg) {
                int res;
                size_t i;
                for (auto c = _container; !c.empty; c.removeFront(), i++) {
                    res = dg(i, c.front);
                    if (res) {
                        return res;
                    }
                }
                return 0;
            }

            override void put(E element) {
                _container.insertBack(element);
            }

            E removeAny() {
                auto result = .moveFront(_container);
                _container.removeFront();
                return result;
            }

            static if (is(typeof(_container.clear()))) {
                void clear() {
                    _container.clear();
                }
            } else {
                void clear() {
                    _container = C.init;
                }
            }

            static if (is(typeof(_container.dup))) {
                /**
                 * Duplicate the queue.
                 */
                ContainerQueue dup() {
                    return new ContainerQueue(_container.dup);
                }
            }

        }
    }
}

/**
 * A queue backed by a DList
 */
alias DListQueue(E) = ContainerQueue!(DList!E);

///
unittest {
    auto q = new DListQueue!int();
    q.put(5);
    q.put(6);
    assert(q.front == 5);
    q.popFront();
    assert(q.front == 6);
    q.popFront();
    assert(q.empty);
}
