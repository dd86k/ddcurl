module main;

import ddcurl.http;
import ddcurl.libcurl : curlVersion;
import std.stdio;
import std.getopt;
import std.string : indexOf, stripLeft;

void quit(int code = 0)
{
    import core.stdc.stdlib : exit;
    exit(code);
}

void main(string[] args)
{
    string[] headers;
    GetoptResult res = void;
    try res = getopt(args, config.caseSensitive,
        "header", "Add header (key:value)", &headers,
        "version", "Show version page and quit", ()
        {
            writeln("cURL version  : ", curlVersion());
            quit;
        }
    );
    catch (Exception ex)
    {
        stderr.writeln("error: ", ex.msg);
        quit(1);
    }
    
    if (res.helpWanted)
    {
        writeln("Usage: ddcurl URL");
        writeln;
        writeln("Options:");
        static immutable int optpad = -16;
        res.options[$-1].help = "Show this help page and quit";
        foreach (Option opt; res.options)
        {
            with (opt) if (optShort)
                writefln(" %s, %*s  %s", optShort, optpad, optLong, help);
            else
                writefln("     %*s  %s", optpad, optLong, help);
        }
        quit;
    }
    
    if (args.length <= 1)
    {
        stderr.writeln("error: Need URL");
        quit(1);
    }
    
    scope HTTPClient client = new HTTPClient();
    
    if (headers)
    {
        foreach (string header; headers)
        {
            if (!header) // safety check
                continue;
            
            ptrdiff_t i = indexOf(header, ':');
            if (i < 0)
                throw new Exception("Key delimiter (':') not found in header");
            if (i == 0)
                throw new Exception("Key delimiter (':') cannot be at begining");
            if (i+1 == header.length)
                throw new Exception("Key delimiter (':') cannot be at end");
            client.addHeader(header[0..i], stripLeft(header[i+1..$]));
        }
    }
    
    foreach (string url; args[1..$])
    {
        HTTPResponse response = client.get(url);
        write(response.text);
    }
}