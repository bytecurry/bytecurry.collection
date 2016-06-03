module bytecurry.container.queue;

import core.exception : RangeError;
import std.algorithm : move;
import std.container: DList, make;
import std.range;
import std.traits : isImplicitlyConvertible;

import bytecurry.container.helpers : ApplyDefinitions;

/**
 * Minimal interface for a queue.
 */
interface Queue(E) {
    /**
     * Check if the queue is empty.
     */
    bool empty() @property;

    /**
     * Look at the item at the front of the queue.
     */
    E front() @property;

    /**
     * Same as `front` but moves the item rather than copy it.
     */
    E moveFront();

    /**
     * Remove the front element from the queue.
     */
    void removeFront();
    /// ditto
    alias stableRemoveFront = removeFront;

    /**
     * Insert an element at the back of the queue.
     */
    size_t insertBack(E element);
    /// ditto
    alias stableInsertBack = insertBack;
    /// ditto
    alias insert = insertBack;
    /// ditto
    alias stableInsert = insertBack;
    /// ditto
    alias linearInsert = insertBack;

    /**
     * Syntactic sugar for appending one or more elements.
     */
    final auto opOpAssign(string op : "~")(E element) {
        insertBack(element);
        return this;
    }

    /// ditto
    final auto opOpAssign(string op : "~", Stuff)(Stuff stuff)
    if (is(typeof({foreach(E el; stuff) {}}))) {
        foreach (el; stuff) {
            insertBack(el);
        }
        return this;
    }

}

/**
 * Test if a type is a queue. That is, you can test if it is empty,
 * remove the front element, look at the front element, and insert an item
 * at the back.
 * I.e. it defines `empty`, `front`, `removeFront`, and `insertBack`
 */
template isQueue(C) {
    enum isQueue = is(typeof((inout int = 0) {
                C c = C.init;
                if (c.empty) {} // can test for empty
                c.removeFront(); // can remove front
                auto h = c.front; // can get front
                c.insertBack(h); // can insert at back
            }));
}

/**
 * A richer interface for a queue.
 * It makes a queue a forward range and an output range, and provides
 * default implementations for several methods.
 */
abstract class RichQueue(E): Queue!E, ForwardRange!E, OutputRange!E {

    abstract void clear();

    /**
     * Remove the front element of the queue and return it.
     */
    E removeAny() {
        auto ret = moveFront();
        removeFront();
        return ret;
    }

    void popFront() {
        removeFront();
    }

    void put(E element) {
        insertBack(element);
    }

    /**
     * Default implementation of opApply.
     * It continually pops values off the front of the queue until
     * the queue is empty.
     *
     * Implementation may want to override to avoid virtual function calls.
     */
    mixin ApplyDefinitions!(E, "empty", "front", "removeFront()");
}

/**
 * A simple queue type implemented with a single linked list.
 *
 */
class SListQueue(E): RichQueue!E {

    /**
     * Create a new queue that is pre-initialized with some elements.
     */
    this(U : E)(U[] elements...) {
        insertBack(elements);
    }

    /**
     * Create a new queue pre-initialized with the contents of an input range.
     */
    this(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, E) && !is(Stuff == E[])) {
        insertBack(stuff);
    }

    // Range operations:
    /**
     * Check if the queue is empty.
     *
     * Complexity: $(BIGOH 1)
     */
    bool empty() @property pure @safe nothrow const {
        return  _front is null;
    }

    /**
     * Peek at the first element of the queue.
     *
     * Complexity: $(BIGOH 1)
     */
    E front() @property {
        assert(!empty, "Queue.front: Queue is empty");
        return _front.value;
    }

    /**
     * Moves the front out and returns it. Leaves `front` in a state
     * that does not allocate any resources.
     *
     * Complexity: $(BIGOH 1)
     */
    E moveFront() {
        return move(_front.value);
    }

    /**
     * Pop the front element off of the queue
     *
     * Complexity: $(BIGOH 1)
     */
    void removeFront() pure @safe {
        assert(!empty, "Queue.popFront: Queue is empty");
        _front = _front.next;
        if (_front is null) {
            _back = null;
        }
    }

    /**
     * Return a forward range over the remaining elements in the queue.
     * Popping elements off the front of the queue has no affect on this range,
     * but if additional items are pushed onto the queue before the range has been
     * emptied, those will be included in the saved range.
     */
    Range save() nothrow {
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
    override {
        mixin ApplyDefinitions!(E, q{_front is null}, q{_front.value}, q{_front = _front.next});
    }

    /**
     * Add an element or a range of elements at the back of the queue.
     */
    size_t insertBack(E element) pure nothrow @safe {
        auto node = new Node(element);
        if (_back) {
            _back.next = node;
        } else {
            _front = node;
        }
        _back = node;
        return 1;
    }

    /**
     * Optimization to insert multiple elements at a time.
     */
    size_t insertBack(Stuff)(Stuff stuff)
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
RichQueue!E queue(E)(E[] elements...) pure @safe {
    return new SListQueue!E(elements);
}


///
unittest {
    import std.range;
    import std.algorithm : equal;

    RichQueue!int q = queue!int();
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
    assert(equal(q, [1,2,3,4,5]));
    assert(q.empty);
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
    RichQueue!int q1 = queue!int();
    RichQueue!int q2 = queue!int();

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
 * A Queue backed by a container with the following characteristics:
 * The following container methods are defined: `empty`, `front`, `removeFront`, `insertBack`,
 * and `opSlice` is defined and returns a forward range.
 */
template ContainerQueue(C) if (isQueue!C && isForwardRange!(typeof(C.init.opSlice()))) {
    private alias E = ElementType!C;
    static if (is(C: Queue!E)) {
        alias ContainerQueue = C;
    } else {
        class ContainerQueue: RichQueue!E {
            protected C _container;

            this() {
                _container = make!C();
            }

            this(E[] elements...) {
                _container = make!C(elements);
            }

            this(C container) {
                _container = container;
            }

            bool empty() @property {
                return _container.empty;
            }

            E front() @property {
                return _container.front;
            }

            E moveFront() {
                return .moveFront(_container);
            }

            void removeFront() {
                _container.removeFront();
            }

            size_t insertBack(E element) {
                auto ret = _container.insertBack(element);
                static if(is(typeof(ret): size_t)) {
                    return ret;
                } else {
                    return 1;
                }
            }


            ForwardRange!E save() {
                return inputRangeObject(_container.opSlice());
            }

            override void clear() {
                static if (is(typeof(_container.clear()))) {
                    _container.clear();
                } else {
                    _container = make!C();
                }
            }

            override {
                mixin ApplyDefinitions!(E, q{_container.empty}, q{_container.front},
                                        q{_container.removeFront()});
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
