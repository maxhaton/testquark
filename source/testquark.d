module testquark;
import std.stdio;
import std.json;
import std.algorithm;
import std.traits;
import std.array;
import std.math;

///Required to indicate what is measurable.
struct NamedBenchmark
{

	string name;
	string module_;
	int line;
	this(string n, int l = __LINE__, string f = __MODULE__)
	{
		name = n;
		line = l;
		module_ = f;
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
///Enables timing of unittests, call runTests
template TimeTests(alias that)
{
	version (unittest)
	{
		alias tests = __traits(getUnitTests, that);

		/** 
		 * Measure tests in a naive manner

		 * Params:
		 *   iters = How many iterations to time each test

		 * Returns: JSONValue containing collected data
		 */
		JSONValue runTests(size_t iters)
		{
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

			TestResult[] tmp;

			foreach (test; tests)
			{
				if (hasUDA!(test, NamedBenchmark))
				{
					float[] usEachRun = new float[iters];

					const tag = getUDAs!(test, NamedBenchmark)[0];
					writef!("Measuring test %s from %s now\n")(tag.name, tag.module_);
					auto res = TestResult(tag);

					//Get data
					foreach (ref i; usEachRun)
					{
						import std.datetime.stopwatch;
						//Time the fucker
						auto sw = StopWatch(AutoStart.no);
						sw.start();

						test();

						sw.stop();

						i = cast(float) sw.peek.total!"usecs";
						
					}

					//Process data
					res.mean = sum(usEachRun) / iters;
					res.min = minElement(usEachRun);
					res.max = maxElement(usEachRun);
					//Mean of the squares minus the square of the mean is wot i was taught init
					import dstats.summary : stdev;
					res.stdandardDeviation = usEachRun.stdev;
					//writeln(JSONValue(usEachRun).toPrettyString);
					tmp ~= res;
				}
			}
			return JSONValue(tmp.map!(x => x.toJson).array);
		}
	}
}


/** Hijacks your main function and runs the tests in mod.
 *  mixin this to inject a C main that initializes the runtime and prints the tests etc.
 * 
 * Params:
 *   mod = Where to gets the tests from
 */
template HijackMain(alias mod)
{
	pragma(mangle, "main")
	extern(C)
	int main()
	{
		import core.runtime;
		import std.stdio;
		rt_init;
		alias runThis = TimeTests!mod;
		write("Iterations: \n");
		size_t iters;
		readf!"%d\n"(iters);
		
		puts("\n");
		

		writeln(runThis.runTests(iters).toPrettyString());

		
		rt_term();
		return 0;
	}
}
///just to get some compilation errors
@NamedBenchmark("test1") unittest
{
	foreach(_; 0..10_000)
	{

	}
}

///
@NamedBenchmark("main") unittest
{
	//alias g = TimeTests!testquark;
}

//version(unittest)
	//mixin HijackMain!testquark;