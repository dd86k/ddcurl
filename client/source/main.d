module main;

import ddcurl.http;
import std.stdio;
import std.getopt;

void quit(int code = 0)
{
    import core.stdc.stdlib : exit;
    exit(code);
}

void main(string[] args)
{
    GetoptResult res = void;
    try res = getopt(args, config.caseSensitive,
    );
    catch (Exception ex)
    {
        stderr.writeln("error: ", ex.msg);
        quit(1);
    }
    
    if (res.helpWanted)
    {
        writeln("Usage:");
        writeln(" ddcurl URL");
        quit;
    }
    
    if (args.length <= 1)
    {
        stderr.writeln("error: Need URL");
        quit(1);
    }
    
    scope HTTPClient client = new HTTPClient();
    foreach (string url; args[1..$])
    {
        HTTPResponse response = client.get(url);
        write(response.text);
    }
}