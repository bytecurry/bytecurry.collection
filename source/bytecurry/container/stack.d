module bytecurry.container.stack;

import std.container.util : make;
import std.container.slist;
import std.range;
import std.traits : isImplicitlyConvertible;

import bytecurry.container.helpers : ApplyDefinitions;

/**
 * Minimal interface for a stack.
 */
interface Stack(E) {
    /**
     * Check if the stack is empty.
     */
    bool empty() @property;

    /**
     * Remove the front element from the stack
     */
    void removeFront();
    /// ditto
    alias stableRemoveFront = removeFront;

    /**
     * Get the top element of the stack;
     */
    E front() @property;

    /**
     * Like `front` but moves the
     * front value rather than copying.
     */
    E moveFront();

    /**
     * Insert an element at the end of the stack.
     */
    size_t insertFront(E element);
    /// ditto
    alias stableInsertFront = insertFront;
    /// ditto
    alias insert = insertFront;
    /// ditto
    alias stableInsert = insertFront;
    /// ditto
    alias linearInsert = insertFront;
}

/**
 * Test if a type is a stack. That is,
 * you can test if it is empty, remove the front element,
 * look at the front element, and insert an item in the front.
 * I.e. it defines `empty`, `front`, `removeFront`, and `insertFront`
 */
template isStack(C) {
    enum isStack = is(typeof((inout int = 0) {
            C c = C.init;
            if (c.empty) {} // can test for empty
            c.removeFront(); // can remove front
            auto h = c.front; // can get front
            c.insertFront(h); // can insert at font
            }));
}

/**
 * A richer interface for a stack.
 * It makes a stack a forward range and an output range, and provides
 * default implementations for several methods.
 */
abstract class RichStack(E) : Stack!E, ForwardRange!E, OutputRange!E {
    // new methods

    /**
     * Clear all elements from the stack.
     */
    abstract void clear();

    /**
     * Remove the top element of the stack and return it.
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
        insertFront(element);
    }

    /**
     * Default implementation of opApply.
     * It calls empty, front, and removeFront.
     *
     * Implementations may want to override to avoid
     * virtual function calls.
     */
    mixin ApplyDefinitions!(E, "empty", "front", "removeFront()");
}

/**
 * Class that wraps another container that acts like a stack.
 */
template ContainerStack(C) if (isStack!C && isForwardRange!(typeof(C.init.opSlice()))) {
    private alias E = ElementType!C;
    static if (is(C : Stack!E)) {
        alias ContainerStack = C;
    } else {
        class ContainerStack: RichStack!E {
            protected C _container;
            this(C cont) {
                _container = cont;
            }

            this() {
                _container = make!C();
            }

            this(E[] elements...) {
                _container = make!C(elements);
            }

            this(Stuff)(Stuff stuff) if (isInputRange!Stuff && is(ElementType!Stuff: E)) {
                _container = make!C(stuff);
            }

            bool empty() @property {
                return _container.empty;
            }

            void removeFront() {
                _container.removeFront();
            }

            E front() @property {
                return _container.front;
            }

            E moveFront() {
                return .moveFront(_container);
            }

            size_t insertFront(E element) {
                return _container.insertFront(element);
            }

            override void clear() {
                static if (is(typeof(_container.clear()))) {
                    _container.clear();
                } else {
                    _container = C.init;
                }
            }

            ForwardRange!E save() {
                return inputRangeObject(_container.opSlice());
            }

            static if (is(typeof(_container.dup))) {
                /**
                 * Duplicate the stack
                 */
                ContainerStack dup() @property {
                    return new ContainerStack(_container.dup);
                }
            }

            override bool opEquals(Object o) {
                auto rhs = cast(ContainerStack) o;
                if (rhs) {
                    return _container == rhs._container;
                } else {
                    return false;
                }
            }
        }
    }
}



/**
 * A simple stack interface that wraps an SList.
 *
 */
alias SListStack(E) = ContainerStack!(SList!E);

/**
 * Create a new stack initialized with zero or more
 * elements.
 */
RichStack!E stack(E)(E[] elements...) {
    return new SListStack!E(elements);
}

///
unittest {
    RichStack!int stack = stack!int();

    stack.put(1);
    stack.put(5);
    stack.put(10);
    assert(stack.front == 10);
    stack.popFront();
    assert(stack.removeAny() == 5);
    assert(stack.removeAny() == 1);
    assert(stack.empty);
}

unittest {
    auto stack = stack!int();
    stack.put(1);
    stack.insertFront(2);
    stack.clear();
    assert(stack.empty);
}
