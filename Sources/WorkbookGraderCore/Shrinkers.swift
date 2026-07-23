//  Shrinkers.swift — reduction strategies for the shapes the workbook generates.
//
//  Language-neutral and engine-free, like the rest of Core: a shrinker is just
//  "given a failing input, what simpler inputs should I try?" A port supplies its
//  own, or — as the Hypothesis binding does — delegates to an engine that already
//  shrinks.
//
//  Every strategy here is ordered *simplest-first*, because the grader takes the
//  first candidate that still fails. Ordering is the whole design: yield the
//  aggressive reductions early so the common case converges in a few passes.

/// Reduction strategies for common input shapes.
public enum Shrinkers {

    /// Simpler integers, ordered: zero, halves toward zero, one step toward zero,
    /// and the positive twin of a negative.
    ///
    /// Halving first is what makes this fast: reducing 10_000 one step at a time
    /// would take 10_000 property runs, while halving reaches 0 in fourteen.
    public static func integer(_ value: Int) -> [Int] {
        guard value != 0 else { return [] }

        var candidates: [Int] = [0]
        // Halve toward zero. `value / 2` is already truncating, so this
        // terminates at 0 without a special case.
        var step = value / 2
        while step != 0 {
            candidates.append(value - step)
            step /= 2
        }
        if value < 0, value != Int.min { candidates.append(-value) }

        // Preserve simplest-first order while removing duplicates and the
        // input itself (a candidate equal to `value` would not be progress).
        var seen = Set<Int>([value])
        return candidates.filter { seen.insert($0).inserted }
    }

    /// Simpler arrays: fewer elements first, then simpler elements.
    ///
    /// Length reductions come first and in decreasing aggressiveness — empty,
    /// each half, then single-element removals — because a shorter array is
    /// almost always the more legible counterexample. Only once the length is
    /// minimal does reducing individual elements matter.
    ///
    /// - Parameters:
    ///   - values: the failing array.
    ///   - element: how to simplify one element. Defaults to no element
    ///     reduction, which still shortens the array.
    public static func array<Element>(
        _ values: [Element],
        element: (Element) -> [Element] = { _ in [] }
    ) -> [[Element]] {
        guard !values.isEmpty else { return [] }

        var candidates: [[Element]] = []

        // 1. Drop everything.
        candidates.append([])

        // 2. Drop each half — the fast path out of a long array.
        if values.count > 1 {
            let middle = values.count / 2
            candidates.append(Array(values[..<middle]))
            candidates.append(Array(values[middle...]))
        }

        // 3. Drop one element at a time, from the front — the front is where
        //    incidental prefix noise accumulates.
        for index in values.indices {
            var shortened = values
            shortened.remove(at: index)
            candidates.append(shortened)
        }

        // 4. Same length, simpler elements.
        for index in values.indices {
            for simpler in element(values[index]) {
                var reduced = values
                reduced[index] = simpler
                candidates.append(reduced)
            }
        }

        return candidates
    }
}
