import Foundation
public import Spring
import Testing

extension Double: @retroactive Exponential.`Protocol` {
    public static func exp(_ x: Double) -> Double { Foundation.exp(x) }
    public static func expm1(_ x: Double) -> Double { Foundation.expm1(x) }
    public static func exp2(_ x: Double) -> Double { Foundation.exp2(x) }
    public static func log(_ x: Double) -> Double { Foundation.log(x) }
    public static func log1p(_ x: Double) -> Double { Foundation.log1p(x) }
    public static func log2(_ x: Double) -> Double { Foundation.log2(x) }
    public static func log10(_ x: Double) -> Double { Foundation.log10(x) }
}

extension Double: @retroactive Trigonometry.Circular {
    public static func sin(_ x: Double) -> Double { Foundation.sin(x) }
    public static func cos(_ x: Double) -> Double { Foundation.cos(x) }
    public static func tan(_ x: Double) -> Double { Foundation.tan(x) }
    public static func asin(_ x: Double) -> Double { Foundation.asin(x) }
    public static func acos(_ x: Double) -> Double { Foundation.acos(x) }
    public static func atan(_ x: Double) -> Double { Foundation.atan(x) }
    public static func atan2(_ y: Double, _ x: Double) -> Double { Foundation.atan2(y, x) }
}

enum `Spring Tests` {}

extension `Spring Tests` {
    fileprivate typealias State = Spring<Double>.State

    /// One spring per regime, and an undamped one, with unequal mass, stiffness and damping.
    fileprivate static func springs() throws(Spring<Double>.Error) -> [Spring<Double>] {
        [
            try Spring(mass: 2, stiffness: 50, damping: 0),
            try Spring(mass: 2, stiffness: 50, damping: 3),
            try Spring(mass: 2, stiffness: 50, damping: 20),
            try Spring(mass: 2, stiffness: 50, damping: 45),
        ]
    }

    fileprivate static let starts: [State] = [
        .released,
        State(displacement: 0, velocity: 3),
        State(displacement: -0.7, velocity: 2.5),
        State(displacement: 1, velocity: -40),
    ]

    fileprivate static func close(_ first: State, _ second: State, within tolerance: Double) -> Bool {
        abs(first.displacement - second.displacement) <= tolerance && abs(first.velocity - second.velocity) <= tolerance
    }
}

extension `Spring Tests` {
    @Suite
    struct Description {
        @Test
        func `A spring has positive finite mass and stiffness and damping that is not negative`() throws {
            let spring = try Spring(mass: 2.0, stiffness: 50, damping: 3)
            #expect(spring.mass == 2 && spring.stiffness == 50 && spring.damping == 3)
            #expect(throws: Spring<Double>.Error.mass) { try Spring(mass: 0.0, stiffness: 1, damping: 1) }
            #expect(throws: Spring<Double>.Error.mass) { try Spring(mass: Double.infinity, stiffness: 1, damping: 1) }
            #expect(throws: Spring<Double>.Error.stiffness) { try Spring(mass: 1.0, stiffness: -1, damping: 1) }
            #expect(throws: Spring<Double>.Error.stiffness) { try Spring(mass: 1.0, stiffness: Double.nan, damping: 1) }
            #expect(throws: Spring<Double>.Error.damping) { try Spring(mass: 1.0, stiffness: 1, damping: -0.1) }
            #expect(throws: Spring<Double>.Error.damping) { try Spring(mass: 1.0, stiffness: 1, damping: Double.infinity) }
        }

        @Test
        func `Frequency, ratio and regime follow from mass, stiffness and damping`() throws {
            let springs = try `Spring Tests`.springs()
            #expect(springs.map(\.regime) == [.under, .under, .critical, .over])
            #expect(springs.allSatisfy { $0.frequency == 5 })
            #expect(springs.map(\.ratio) == [0, 0.15, 1, 2.25])
        }

        @Test
        func `A spring built from frequency and ratio has unit mass and reports both back`() throws {
            let spring = try Spring(frequency: 8.0, ratio: 0.5)
            #expect(spring.mass == 1 && spring.stiffness == 64 && spring.damping == 8)
            #expect(spring.frequency == 8 && spring.ratio == 0.5)
            #expect(try Spring(frequency: 3.0, ratio: 1).regime == .critical)
            #expect(throws: Spring<Double>.Error.stiffness) { try Spring(frequency: 0.0, ratio: 1) }
            #expect(throws: Spring<Double>.Error.stiffness) { try Spring(frequency: 1e200, ratio: 1) }
            #expect(throws: Spring<Double>.Error.damping) { try Spring(frequency: 1.0, ratio: -1) }
        }
    }
}

extension `Spring Tests` {
    @Suite
    struct Motion {
        @Test
        func `At time zero the state is the initial state, exactly`() throws {
            for spring in try `Spring Tests`.springs() {
                for start in `Spring Tests`.starts {
                    #expect(spring.state(at: 0, from: start) == start)
                    #expect(spring.displacement(at: 0, from: start) == start.displacement)
                    #expect(spring.velocity(at: 0, from: start) == start.velocity)
                }
                #expect(spring.state(at: 0) == .released)
            }
        }

        @Test
        func `The state after t plus s is the state after s, started from the state after t`() throws {
            for spring in try `Spring Tests`.springs() {
                for start in `Spring Tests`.starts {
                    for (first, second) in [(0.1, 0.25), (0.75, 0.01), (0.3, 1.2), (1.5, -0.5)] {
                        let direct = spring.state(at: first + second, from: start)
                        let chained = spring.state(at: second, from: spring.state(at: first, from: start))
                        #expect(`Spring Tests`.close(direct, chained, within: 1e-11))
                    }
                }
            }
        }

        @Test
        func `The motion satisfies mass times acceleration plus damping times velocity plus stiffness times displacement equals zero`() throws {
            let step = 1e-5
            for spring in try `Spring Tests`.springs() {
                for start in `Spring Tests`.starts {
                    for time in [0.05, 0.4, 1.1] {
                        let state = spring.state(at: time, from: start)
                        let before = spring.state(at: time - step, from: start)
                        let after = spring.state(at: time + step, from: start)
                        let slope = (after.displacement - before.displacement) / (2 * step)
                        let acceleration = (after.velocity - before.velocity) / (2 * step)
                        #expect(abs(slope - state.velocity) < 1e-5)
                        let residual = spring.mass * acceleration + spring.damping * state.velocity + spring.stiffness * state.displacement
                        #expect(abs(residual) < 1e-4)
                    }
                }
            }
        }

        @Test
        func `An undamped spring released from one is the cosine of frequency times time`() throws {
            let spring = try Spring(mass: 2.0, stiffness: 50, damping: 0)
            for time in [0.1, 0.5, 2, 10] {
                let state = spring.state(at: time)
                #expect(abs(state.displacement - Foundation.cos(5 * time)) < 1e-12)
                #expect(abs(state.velocity + 5 * Foundation.sin(5 * time)) < 1e-11)
            }
        }

        @Test
        func `A critically damped spring released from one never crosses zero and an underdamped one does`() throws {
            let critical = try Spring(frequency: 6.0, ratio: 1)
            let under = try Spring(frequency: 6.0, ratio: 0.2)
            let times = (1...400).map { Double($0) / 100 }
            #expect(times.allSatisfy { critical.displacement(at: $0) > 0 })
            #expect(zip(times, times.dropFirst()).allSatisfy { critical.displacement(at: $0) > critical.displacement(at: $1) })
            #expect(times.contains { under.displacement(at: $0) < 0 })
            #expect(abs(critical.displacement(at: 0.5) - 4 * Foundation.exp(-3)) < 1e-15)
        }

        @Test
        func `The three formulas agree where the damping ratio is close to one`() throws {
            let critical = try Spring(frequency: 6.0, ratio: 1)
            let under = try Spring(frequency: 6.0, ratio: 1 - 1e-6)
            let over = try Spring(frequency: 6.0, ratio: 1 + 1e-6)
            #expect(under.regime == .under && over.regime == .over && critical.regime == .critical)
            for start in `Spring Tests`.starts {
                for time in [0.02, 0.3, 1.5] {
                    let state = critical.state(at: time, from: start)
                    #expect(`Spring Tests`.close(under.state(at: time, from: start), state, within: 1e-4))
                    #expect(`Spring Tests`.close(over.state(at: time, from: start), state, within: 1e-4))
                }
            }
        }

        @Test
        func `Energy never grows, and without damping it stays the same`() throws {
            let springs = try `Spring Tests`.springs()
            let times = (0...200).map { Double($0) / 50 }
            for start in `Spring Tests`.starts {
                for spring in springs.dropFirst() {
                    let energies = times.map { spring.energy(of: spring.state(at: $0, from: start)) }
                    #expect(zip(energies, energies.dropFirst()).allSatisfy { $1 <= $0 * (1 + 1e-12) })
                    #expect(energies[200] < energies[0] / 100)
                }
                let energies = times.map { springs[0].energy(of: springs[0].state(at: $0, from: start)) }
                #expect(energies.allSatisfy { abs($0 - energies[0]) <= energies[0] * 1e-12 })
            }
            #expect(springs[0].energy(of: .released) == 25)
            #expect(springs[0].energy(of: Spring<Double>.State(displacement: 0, velocity: 3)) == 9)
        }
    }
}

extension `Spring Tests` {
    @Suite
    struct Settling {
        @Test
        func `After the settling time the displacement stays within the tolerance`() throws {
            for spring in try `Spring Tests`.springs().dropFirst() {
                for start in `Spring Tests`.starts {
                    for tolerance in [0.1, 1e-3, 1e-6] {
                        let settled = try #require(spring.settling(within: tolerance, from: start))
                        #expect(settled >= 0 && settled.isFinite)
                        let later = (0...2000).map { settled + Double($0) / 250 }
                        #expect(later.allSatisfy { abs(spring.displacement(at: $0, from: start)) <= tolerance })
                    }
                }
            }
        }

        @Test
        func `A spring that starts within the tolerance and can only lose energy has settled at once`() throws {
            let spring = try Spring(frequency: 4.0, ratio: 0.5)
            #expect(spring.settling(within: 2) == 0)
            #expect(spring.settling(within: 0.5, from: Spring<Double>.State(displacement: 0, velocity: 0)) == 0)
            let undamped = try Spring(frequency: 4.0, ratio: 0)
            #expect(undamped.settling(within: 2) == 0)
        }

        @Test
        func `An undamped spring moving beyond the tolerance never settles`() throws {
            let spring = try Spring(frequency: 4.0, ratio: 0)
            #expect(spring.settling(within: 0.5) == nil)
            #expect(spring.settling(within: 0.5, from: Spring<Double>.State(displacement: 0, velocity: 4)) == nil)
        }

        @Test
        func `A stiffer or more heavily underdamped spring settles sooner`() throws {
            let soft = try #require(try Spring(frequency: 4.0, ratio: 0.3).settling(within: 1e-3))
            let stiff = try #require(try Spring(frequency: 8.0, ratio: 0.3).settling(within: 1e-3))
            let damped = try #require(try Spring(frequency: 4.0, ratio: 0.6).settling(within: 1e-3))
            #expect(stiff < soft && damped < soft)
            #expect(abs(stiff - soft / 2) < 1e-12)
        }
    }
}
