module bytecurry.container.treemap;

import std.container.rbtree;
import std.functional : binaryFun;
import std.range : isInputRange, ElementType, Take;
import std.traits : isImplicitlyConvertible;

import bytecurry.container.map;

template TreeMap(K, V, alias less = "a < b")
if (is(typeof(binaryFun!less(const(K).init, const(K).init))))
{
    /**
     * An ordered Map using a Red Black tree.
     */
    class TreeMap : Map!(K, V)
    {
        this() pure
        {
            tree = new Tree();
        }

        this(Tree map)
        {
            tree = map;
        }

        this(Entry[] entries...) pure
        {
            tree = new Tree(entries);
        }

        this(Stuff)(Stuff stuff)
        if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, Entry))
        {
            tree = new Tree(stuff);
        }

        bool empty() @property
        {
            return tree.empty;
        }

        void clear()
        {
            tree.clear();
        }

        V opIndex(K key)
        {
            return rangeForKey(key).front.value;
        }

        void opIndexAssign(V value, K key)
        {
            insert(Entry(key, value));
        }

        void insert(Entry entry)
        {
            //remove any previous values first.
            // necessary because rbtree doesn't replace existing entries
            auto range = tree.equalRange(entry);
            tree.remove(range);
            tree.insert(entry);
        }

        final size_t insert(Stuff)(Stuff stuff)
        if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, Entry))
        {
            return tree.insert(stuff);
        }

        alias stableInsert = insert;

        V get(K key, lazy inout(V) defaultVal)
        {
            auto range = rangeForKey(key);
            if (range.empty)
            {
                return defaultVal;
            }
            else
            {
                return range.front.value;
            }
        }

        bool remove(K key)
        {
            return tree.removeKey(cmpEntry(key)) > 0;
        }

        /**
         * Remove a range of entries from the
         * Map.
         *
         * Returns: The number of entries removed.
         */
        final Tree.Range remove(Tree.Range range)
        {
            return tree.remove(range);
        }

        /// ditto
        final Tree.Range remove(Take!(Tree.Range) range)
        {
            return tree.remove(range);
        }

        /**
         * Remove a single entry from the
         * Map and return it.
         */
        final Entry removeAny()
        {
            return tree.removeAny();
        }

        bool contains(K key) const
        {
            return cmpEntry(key) in tree;
        }

        import std.algorithm : map;
        import std.range : inputRangeObject, BidirectionalRange;

        override BidirectionalRange!K byKey() @property
        {
            return inputRangeObject(tree[].map!(a => a.key));
        }

        override BidirectionalRange!V byValue() @property
        {
            return inputRangeObject(tree[].map!(a => a.value));
        }

        override BidirectionalRange!Entry byKeyValue() @property
        {
            return inputRangeObject(tree[]);
        }

        int opApply(int delegate(K key, ref V value) dg)
        {
            int ret = 0;
            foreach (entry; tree[])
            {
                ret = dg(entry.key, entry.value);
                if (ret) return ret;
            }
            return ret;
        }

        /**
         * Get a range of all entries in the map
         * whose keys are greater than `key`.
         */
        final auto upperBound(K key) pure inout {
            return tree.upperBound(cmpEntry(key));
        }

        /**
         * Get a range of all entries in the map
         * whose keys are less than `key`.
         */
        final auto lowerBound(K key) pure inout {
            return tree.lowerBound(cmpEntry(key));
        }

        override bool opEquals(Object other)
        {
            if (this is other) return true;
            auto otherMap = cast(TreeMap) other;
            return otherMap && otherMap.tree == tree;
        }

        TreeMap dup() @property
        {
            return new TreeMap(tree.dup);
        }

        /**
         * Returns: The number of entries in the map.
         */
        @property size_t length() const pure {
            return tree.length();
        }

    private:

        Tree.Range rangeForKey(K key)
        {
            return tree.equalRange(cmpEntry(key));
        }

        static Entry cmpEntry(K key)
        {
            Entry entry;
            entry.key = key;
            return entry;
        }
        alias Tree = RedBlackTree!(Entry, (a, b) => binaryFun!less(a.key, b.key));
        Tree tree;
    }
}

///
unittest
{
    auto map = new TreeMap!(string, int)();
    assert(map.empty);
    map["a"] = 5;
    assert(map["a"] == 5);
    assert(map.contains("a"));
    assert("a" in map);
    assert(map.get("a", 0) == 5);
    assert(!map.empty);

    map.remove("a");
    assert(map.empty);
    assert("a" !in map);

    map["a"] = 1;
    map["b"] = 2;
    map["c"] = 3;

    import std.algorithm : equal;
    assert(equal(map.byKey(), ["a", "b", "c"]));
    assert(equal(map.byValue(), [1, 2, 3]));

    map["a"] = 10;
    assert(map["a"] == 10);

    auto map2 = new TreeMap!(string, int)();

    foreach (key, value; map)
    {
        map2[key] = value;
    }

    assert(map2 == map);
    map2.clear();

    foreach(entry; map.byKeyValue())
    {
        map2[entry.key] = entry.value;
    }
    assert(map2 == map);

    map2 = map.dup;
    assert(map2 == map);
    assert(map2 !is map);

    map.clear();
    assert(map.empty());

    map.insert(mapEntry("b", 4));
    assert(map["b"] == 4);
    map.insert(mapEntry("b", 1));
    assert(map["b"] == 1);
}
