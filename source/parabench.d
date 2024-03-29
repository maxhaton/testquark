///Parameterize a benchmark
module testquark.parabench;
//An unfortunate requirement.
public import testquark.defines;
import std.range;
import std.traits;
import std.typecons;
import std.json;
import std.stdio;
/** Define a way of providing testing data to a benchmark,
 *  i.e. stop the compiler DFAing the magic away. It must be 
 *  parameterized by a size_t such that it can be measured.
 *
 *  You provide the generating algorithm and a range to specify
 */
struct ParameterizerStruct(Range, FuncType)
        if (isInputRange!Range && is(ElementType!Range : size_t) && (isCallable!FuncType
            && arity!FuncType == 1 && __traits(isSame, Parameters!FuncType[0], size_t)))
{
    NamedBenchmark loc;
    Range store;
    FuncType func;
    ///If you already have the location
    this(NamedBenchmark l, Range set, FuncType fSet)
    {
        loc = l;
        store = set;
        func = fSet;

    }
    ///
    this(string name, Range set, FuncType fSet)
    {
        //loc = NamedBenchmark(name, line, file);
        store = set;
        func = fSet;

    }

}
///Split up operation for exposing to afar
struct Operation
{
    //Size of task
    size_t size;

    //This atomizes the actual task in hand so it can be timed/measured externally
    void delegate() runIt;
    invariant(runIt !is null);
}
///Abstract range interface to a benchmark for some type erasure
interface BenchmarkPrototype : InputRange!(Operation)
{
    @property Operation front();
    void popFront();
    bool empty();
    const size_t iterationsPerMeasurement();
}

auto godawfulHack(RetType_, RangeType_, FuncType_, Operation_, alias Item_, I, J, K, L)(I x, J y, K z, L fuck)
{
    return new class (x, y, z, fuck) BenchmarkPrototype
                        {
                            RetType_ actOnThisData;
                            RangeType_ theRange;
                            FuncType_ theFunction;
                            Operation_ current;
                            NamedBenchmark loc;
                            typeof(&Item_) benchFunc;
                            @property Operation front()
                            {
                                return current;
                            }

                            size_t iterationsPerMeasurement() const
                            {
                                return loc.iterations;
                            }

                            void generateData()
                            {
                                current.runIt = &runTask;
                                actOnThisData = theFunction(current.size);

                            }

                            void popFront()
                            {
                                //writeln("popped", theRange.empty);
                                theRange.popFront;
                                
                                if(!theRange.empty) current.size = theRange.moveFront;
                                generateData();
                            }

                            void runTask()
                            {
                                benchFunc(actOnThisData);
                            }

                            bool empty()
                            {
                                return theRange.empty;
                            }
                            Operation moveFront()
                            {
                                //writeln("moved");
                                return current;
                            }
                            int opApply(scope int delegate(Operation) it)
                            {
                                //writeln("opapplied");
                                while(!empty)
                                {
                                    it(this.current);
                                    if(!theRange.empty) this.popFront();
                                }
                                return 0;
                            }
                            int opApply(scope int delegate(ulong, Operation))
                            {
                                assert(0, "nonsensical construct");
                                
                            }

                            this(NamedBenchmark sLoc, RangeType_ set, FuncType_ task, typeof(&Item_) setB)
                            {
                                theFunction = task;
                                theRange = set;
                                loc = sLoc;
                                //current = Operation(theRange.front, &this.runTask);
                                benchFunc = setB;
                                generateData;
                            }
                        };
}
auto MarkImpl(alias mod)(ref BenchmarkPrototype[NamedBenchmark] map)
{
    
    void register(NamedBenchmark key, BenchmarkPrototype set)
    {   
        map[key] = set;
    }
    foreach (sItem; __traits(allMembers, mod))
    {
        
        import std.stdio;

        alias Item = __traits(getMember, mod, sItem);
        const theAttributes = __traits(getAttributes, Item);
        //pragma(msg, sItem, " ", theAttributes.length);
        //No attributes 
        static if (theAttributes.length & isCallable!Item)
        {
            
            foreach (attr; theAttributes)
            {
                if (is(typeof(attr) : Template!Args, alias Template, Args...))
                {
                    if (__traits(isSame, Template, ParameterizerStruct))
                    {
                        //pragma(msg, attr);
                        //pragma(msg, Args);
                        alias RangeType = Args[0];
                        alias FuncType = Args[1];

                        alias RetType = ReturnType!FuncType;
                        //pragma(msg, sItem);
                        static assert(__traits(isSame, RetType, Parameters!Item[0]),
                                "Functioning being benchmarked is not callable with data provided by parameterizer");
                        {
                        register(attr.loc, godawfulHack!(RetType, RangeType, FuncType, Operation, Item, typeof(attr.loc), typeof(attr.store), typeof(attr.func), typeof(&Item))(attr.loc, attr.store, attr.func, &Item));
                        }
                    }
                }

            }
        }

    }
    return map;
}


pragma(lib, "papi");

auto runThem(Flag!"UsePapi" usePapi = Yes.UsePapi)(BenchmarkPrototype[NamedBenchmark] theBenchmarks, Flag!"FullData" fullDataView = No.FullData)
{
        static if(usePapi)
        {
            pragma(msg, "Link with PAPI 5 for this to work, pragma(lib, \"papi\") should work\nSet a very low perf_paranoid");
            //pragma(lib, "papi");
        }
        JSONValue runBenchmark(BenchmarkPrototype bench)
            in(bench !is null, "Null pointer")
        {
            import std.conv : to;
            ulong[string][string] data;
            foreach (pair; bench)
            {
                long totalMeasured = 0;
                foreach (i; 0 .. bench.iterationsPerMeasurement)
                {
                    
                    import std.datetime.stopwatch : StopWatch;
                    static if (usePapi) {
                        import testquark.papi;
                        import testquark.papiStdEventDefs;

                        enum numCounters = 1;
                        long[numCounters] values;

                        int[numCounters] eventSet = [PAPI_TOT_INS];

                        if (PAPI_start_counters(eventSet.ptr, numCounters) != PAPI_OK)
                            assert(0, "Papi Initialization failed");
                        
                        pair.runIt();
                        //if (PAPI_read_counters(values.ptr, numCounters) != PAPI_OK)
                                //assert(0, "Failed reading counters");
                        
                        if (PAPI_stop_counters(values.ptr, numCounters) != PAPI_OK)
                            assert(0, "Failing stopping counters?!");

                        const long measured = values[0];
                    } else {
                        auto sw = StopWatch(No.autoStart);
                        sw.start();
                        pair.runIt();
                        sw.stop();
                        const long measured = sw.peek.total!"usecs";
                    }
                    
                    totalMeasured += measured;
                    if(fullDataView)
                        data[pair.size.to!string][i.to!string] = measured;
                }
                static if (usePapi)
                {
                    enum name = "meaninstructions";
                }
                else {
                     enum name = "meanUsecs";
                }
                data[pair.size.to!string][name] =  cast(ulong) (cast(float) totalMeasured / bench.iterationsPerMeasurement);

            }

            return JSONValue(data);
        }

        //writeln(theBenchmarks.length);
        //theBenchmarks.length
        ulong index = 0;
        auto tmp = JSONValue(iota(index, theBenchmarks.length + 1).array);
        foreach (NamedBenchmark key, value; theBenchmarks)
        {
            
            tmp[index].object(["fullDefinition" :key.toJson, "data": runBenchmark(value)]);
            //tmp[key.name]["data"] = runBenchmark(value);
            index += 1;
        }
        return tmp;
}
/** Mix this in to gain the power of benchmarks, if on auto they will run on module destruction
 * 
 * Params:
*    expose = Expose to benchquark proper
 */
template BenchmarkInfrastructure(Flag!"Expose" expose = No.Expose, string M = __MODULE__)
{
    BenchmarkPrototype[NamedBenchmark] benchmarks;
    void setup()
    {
        benchmarks = MarkImpl!(mixin(M))(benchmarks);
    }
    void runAndPrint(Flag!"UsePapi" usePapi)()
    {
        setup();
        runThem!usePapi(benchmarks).toPrettyString.writeln;
    }
}

///Use these (unless you want to manually specify range types into ParameterizeStruct)
public auto Parameterizer(Range, FuncType)(string name, Range x, FuncType func,
        size_t iter = 1, string f = __FILE__, int l = __LINE__)
{
    return Parameterizer!(Range, FuncType)(NamedBenchmark(name, iter, l, f), x, func);
}
///Use these (unless you want to manually specify range types into ParameterizeStruct)
public auto Parameterizer(Range, FuncType)(NamedBenchmark loc, Range x, FuncType func)
{
    return ParameterizerStruct!(Range, FuncType)(loc, x, func);
}
///A simple benchmark involving specifying a sorting function




