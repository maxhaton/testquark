# testquark
This is a nearly-finished benchmarking framework. 
Use as follows
```
int[] generate(size_t x) ///Sanity cheque!
    out(v; v.length == x)
{
    auto tmp = new int[x];
    foreach (ref i; tmp)
    {
        import std.random;
        i = uniform(int.min, int.max);
    }
    return tmp;
}
//                                                              V You specify the range over which to test here
@Parameterizer("Measure [our new favourite] sorting algorithm", iota(1, 300), &generate)
//                                                                            ^ Generate your own data, e.g. array[N]
int[] sort(int[] data)
//         ^Generic, but built for arrays
{
    import std.algorithm : sort;
    return data.sort.array;
}
//This is then triggered elsewhere, i.e. 
//mixin BenchmarkInfrastructure!(No.Expose);

```

You will soon be able to use benchquark to measure performance counters of your benchmarks (e.g. cache, Instructions executed and 
what the branch predictors been up to) by choosing `Yes.Expose`
