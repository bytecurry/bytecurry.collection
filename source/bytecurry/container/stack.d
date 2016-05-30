module bytecurry.container.stack;

import std.container.slist;
import std.range : isInputRange;
import std.traits : isImplicitlyConvertible;

/**
 * A simple stack interface that wraps an SList.
 *
 */
struct Stack(T) {

    /**
     * Create a Stack from an underlying SList.
     * Note that the slist and stack share data.
     */
    this(SList!T slist) pure {
        list = slist;
    }

    /**
     * Construct, initialized with a number of values.
     * The first value is at the top of the stack.
     */
    this(U)(U[] values...) pure if (isImplicitlyConvertible!(U, T)) {
        list = Slist!T(values);
    }

    /**
     * Construct, initialized with values from an input range.
     * The first value of the range is at the top of the stack.
     */
    this(Stuff)(Stuff stuff) pure
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T) && !is(Stuff == T[])) {
        list = Slist!T(stuff);
    }

    /**
     * Property returning `true` if and only if the stack is empty.
     *
     * Complexity: $(BIGOH 1)
     */
    @property bool empty() const pure {
        return list.empty;
    }

    /**
     * Property returning the top element in the stack.
     */
    @property ref T front() pure {
        return list.front;
    }

     /**
      * Return a range of the underlying SList
      */
    auto save() pure {
        return list[];
    }
    alias opSlice = save;

    /**
     * Remove the top element from the stack.
     *
     * Complexity: $(BIGOH 1)
     */
    void popFront() pure {
        list.removeFront();
    }
    /// ditto
    alias removeFront = popFront;
    alias stableRemoveFront = popFront;

    /**
     * Remove the top element from the stack and return it.
     *
     * Complexity: $(BIGOH 1)
     */
    T removeAny() pure {
        return list.removeAny();
    }
    alias stableRemoveAny = removeAny;

     /**
      * Push one or more items onto the top of the stack. If more than
      * one item is pushed, the first item is on top.
      *
      * Complexity: $(BIGOH m) where `m` is the length of `stuff`
      */
    void put(T item) pure {
        list.insertFront(item);
    }

     /// ditto
    void put(Stuff)(Stuff stuff) pure
    if (isInputRange!Stuff && isImplicitlyConvertible(ElementType!Stuff, T)) {
         list.insertFront(stuff);
    }

    /// ditto
    alias insert = put;
    /// ditto
    alias stableInsert = put;
    /// ditto
    alias insertFront = put;
    /// ditto
    alias stableInsertFront = put;

    /**
     * Comparison for equality.
     *
     * Complexity: $(BIGOH min(n, m)) where `m` is the number of elements in `rhs`
     */
    bool opEquals(const Stack rhs) pure const {
        return opEquals(rhs);
    }

    /// ditto
    bool opEquals(const ref Stack rhs) pure const {
        return list == rhs.list;
    }

    /**
     * Duplicate the stack.
     *
     * Complexity: $(BIGOH n)
     */
    Stack dup() pure {
        return Stack(list.dup);
    }

    /**
     * Remove all contents of the stack.
     *
     * Complexity: $(BIGOH 1)
     */
    void clear() pure {
        list.clear();
    }


    private SList!T list;
}

///
unittest {
    Stack!int stack;

    stack.put(1);
    stack.put(5);
    stack.put(10);
    assert(stack.front == 10);
    stack.popFront();
    assert(stack.removeAny() == 5);
    assert(stack.removeAny() == 1);
    assert(stack.empty);
}
