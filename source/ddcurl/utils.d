module ddcurl.utils;

import core.stdc.string : memcpy;
import core.stdc.stdlib : malloc, realloc, free;
import ddlogger;

package
struct MemoryBuffer
{
    /// Initial capacity, if not yet resized.
    enum INITCAP = 2048;
    void *buffer;
    size_t capacity;
    size_t length;
    
    ~this()
    {
        close();
    }
    
    void reset()
    {
        length = 0;
        // This helps long-lived sessions (e.g., client services)
        // when a client previously receives a much larger response than
        // the initial capacity. Plus, when having small replies, there's
        // no point in unconditionally resizing the buffer, which could be
        // wasteful towards realloc.
        if (length > INITCAP) resize(INITCAP);
    }
    
    void append(void *data, size_t size)
    {
        logTrace("data=%s size=%u", data, size);
        
        if (data == null)
            throw new Exception("data pointer null");
        if (size == 0)
            return;
        
        // If the current capacity cannot hold the new size,
        // resize it to the current length+size. Otherwise,
        // even when the capacity is zero, it will be allocated
        // to size (for the first allocation).
        if (length + size > capacity)
        {
            size_t newcap = length + size;
            assert(newcap >= size, "new capacity cannot hold size"); // overflow
            resize(newcap);
        }
        
        memcpy(buffer + length, data, size);
        length += size;
    }
    
    void resize(size_t newsize)
    {
        logTrace(".buffer=%s .cap=%u .len=%u newsize=%u", buffer, capacity, length, newsize);
        void *temp = realloc(buffer, newsize);
        if (temp == null)
            throw new Exception("Failed to allocate memory buffer");
        buffer = temp;
        capacity = newsize;
    }
    
    void close()
    {
        if (buffer) free(buffer);
        buffer = null;
    }
    
    string toString() const
    {
        return (cast(immutable(char)*)buffer)[0..length];
    }
}
// Initial append
unittest
{
    static immutable ubyte[3] data = [ 1, 2, 3 ];
    MemoryBuffer mem;
    mem.append(cast(void*)data.ptr, data.length);
    mem.append(cast(void*)data.ptr, data.length);
    assert(mem.length == 6);
    assert(mem.capacity >= 6);
    assert(mem.buffer);
    ubyte *p = cast(ubyte*)mem.buffer;
    assert(p[0] == 1);
    assert(p[1] == 2);
    assert(p[2] == 3);
    assert(p[3] == 1);
    assert(p[4] == 2);
    assert(p[5] == 3);
}
// Test errors
unittest
{
    MemoryBuffer mem;
    // Test null pointer
    try
    {
        mem.append(null, 0);
        assert(0); // should throw before reaching
    }
    catch (Exception ex) {}
    
    // Test zero size
    try
    {
        mem.append(cast(void*)0x123456, 0); // should just return
    }
    catch (Exception ex) {}
}
// Test realloc
unittest
{
    ubyte[] data = new ubyte[157];
    data[] = 0;
    
    enum INIT = 60;
    
    MemoryBuffer mem;
    mem.resize(INIT);
    mem.append(cast(void*)data.ptr, data.length);
    
    assert(mem.capacity > 60);
    assert(mem.length == data.length);
}