module defines;
import std.json;
public struct NamedBenchmark
{
	string name;
	string module_;
	int line;
	size_t iterations = 1;
	this(string n, size_t iter = 1, int l = __LINE__, string f = __MODULE__)
	{
		name = n;
		line = l;
		module_ = f;
		iterations = iter;
	}

	JSONValue toJson()
	{
		return JSONValue([
				"name": JSONValue(name),
				"module": JSONValue(module_),
				"defined": JSONValue(line)
				]);
	}
}
template location(alias x, string xx)
{
    enum l = __traits(getLocation, x);
    enum location = NamedBenchmark(xx, l[1], l[0]);
}

package 
struct TestResult
			{
				NamedBenchmark src;
				float mean;
				float min, max;
				float stdandardDeviation;
				this(NamedBenchmark s)
				{
					src = s;
				}

				JSONValue toJson()
				{
					return JSONValue([
							"src": src.toJson,
							"timeUnit": JSONValue("us"),
							"mean": JSONValue(mean),
							"min": JSONValue(min),
							"max": JSONValue(max),
							"standardDeviation": JSONValue(stdandardDeviation)
							]);
				}
			}