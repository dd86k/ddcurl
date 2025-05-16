module ddcurl.utils;

import core.stdc.string : memcpy;
import core.stdc.stdlib : malloc, realloc, free;
import ddlogger;

package
struct MemoryBuffer
{
    void *buffer;
    size_t capacity;
    size_t len;
    enum INITCAP = 1024; /// Initial capacity if not yet sized
    
    ~this()
    {
        close();
    }
    
    void reset()
    {
        len = 0;
    }
    
    void append(void *data, size_t size)
    {
        logTrace("data=%s size=%u", data, size);
        
        if (data == null)
            throw new Exception("data pointer null");
        if (size == 0)
            return;
        if (buffer == null)
            resize(INITCAP);
        
        if (len + size >= capacity)
        {
            resize(capacity ? capacity << 1 : INITCAP); // * 2
        }
        
        memcpy(buffer + len, data, size);
        len += size;
    }
    
    void resize(size_t newsize)
    {
        logTrace(".buffer=%s .capacity=%u .len=%u newsize=%u", buffer, capacity, len, newsize);
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
        return (cast(immutable(char)*)buffer)[0..len];
    }
}
unittest
{
    static immutable ubyte[3] data = [ 1, 2, 3 ];
    MemoryBuffer mem;
    mem.append(cast(void*)data.ptr, data.length);
    mem.append(cast(void*)data.ptr, data.length);
    assert(mem.len == 6);
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
unittest
{
    ubyte[] data = new ubyte[157];
    data[] = 0;
    
    MemoryBuffer mem;
    mem.reset();
    mem.append(cast(void*)data.ptr, data.length);
    
    assert(mem.capacity >= mem.INITCAP);
    assert(mem.len == data.length);
}