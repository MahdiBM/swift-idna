import Benchmark
import FoundationIDNA
import SwiftIDNA

let benchmarks: @Sendable () -> Void = {
    unsafe Benchmark.defaultConfiguration.maxDuration = .seconds(6)

    let strictConfig = IDNA(configuration: .mostStrict)
    let laxConfig = IDNA(configuration: .mostLax)
    let nameAndConfigs = [
        ("Strict", strictConfig),
        ("Lax", laxConfig),
    ]

    /// Swift uses `_SmallString` internally for strings <= 15 utf8s.
    /// We have a benchmark for both `_SmallString` and heap-allocated `String` cases.

    /// Mark: - Lowercased_google.com

    Benchmark(
        "To_ASCII_Lowercased_google_dot_com_CPU_8M",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<8_000_000 {
            var domainName = "google.com"
            domainName = try! strictConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Lowercased_google_dot_com_Malloc",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "google.com"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Lowercased_google_dot_com_Instructions",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "google.com"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Lowercased_google_dot_com_CPU_8M_ICU",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<8_000_000 {
            var domainName = "google.com"
            domainName = UIDNAHookICU.encode(domainName)!
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Lowercased_google_dot_com_Malloc_ICU",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "google.com"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Lowercased_google_dot_com_Instructions_ICU",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "google.com"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    /// Mark: - Uppercased_google.com

    Benchmark(
        "To_ASCII_Uppercased_google_dot_com_CPU_5M",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<5_000_000 {
            var domainName = "GOOGLE.COM"
            domainName = try! strictConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Uppercased_google_dot_com_Malloc",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "GOOGLE.COM"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Uppercased_google_dot_com_Instructions",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "GOOGLE.COM"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Uppercased_google_dot_com_CPU_5M_ICU",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<5_000_000 {
            var domainName = "GOOGLE.COM"
            domainName = UIDNAHookICU.encode(domainName)!
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Uppercased_google_dot_com_Malloc_ICU",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "GOOGLE.COM"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Uppercased_google_dot_com_Instructions_ICU",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "GOOGLE.COM"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    /// Mark: - Lowercased_app-analytics-services.com

    Benchmark(
        "To_ASCII_Lowercased_app-analytics-services_dot_com_CPU_5M",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<5_000_000 {
            var domainName = "app-analytics-services.com"
            domainName = try! strictConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Lowercased_app-analytics-services_dot_com_Malloc",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "app-analytics-services.com"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Lowercased_app-analytics-services_dot_com_Instructions",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "app-analytics-services.com"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Lowercased_app-analytics-services_dot_com_CPU_5M_ICU",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<5_000_000 {
            var domainName = "app-analytics-services.com"
            domainName = UIDNAHookICU.encode(domainName)!
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Lowercased_app-analytics-services_dot_com_Malloc_ICU",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "app-analytics-services.com"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Lowercased_app-analytics-services_dot_com_Instructions_ICU",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "app-analytics-services.com"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    /// Mark: - Uppercased_app-analytics-services.com

    Benchmark(
        "To_ASCII_Uppercased_app-analytics-services_dot_com_CPU_3M",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<3_000_000 {
            var domainName = "APP-ANALYTICS-SERVICES.COM"
            domainName = try! strictConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Uppercased_app-analytics-services_dot_com_Malloc",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "APP-ANALYTICS-SERVICES.COM"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Uppercased_app-analytics-services_dot_com_Instructions",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "APP-ANALYTICS-SERVICES.COM"
        domainName = try! strictConfig.toASCII(domainName: domainName)
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Uppercased_app-analytics-services_dot_com_CPU_3M_ICU",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: 15,
            maxIterations: 1000,
        )
    ) { benchmark in
        for _ in 0..<3_000_000 {
            var domainName = "APP-ANALYTICS-SERVICES.COM"
            domainName = UIDNAHookICU.encode(domainName)!
            blackHole(domainName)
        }
    }

    Benchmark(
        "To_ASCII_Uppercased_app-analytics-services_dot_com_Malloc_ICU",
        configuration: .init(
            metrics: [.mallocCountTotal],
            warmupIterations: 1,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "APP-ANALYTICS-SERVICES.COM"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    Benchmark(
        "To_ASCII_Uppercased_app-analytics-services_dot_com_Instructions_ICU",
        configuration: .init(
            metrics: [.instructions],
            warmupIterations: 10,
            maxIterations: 10,
        )
    ) { benchmark in
        var domainName = "APP-ANALYTICS-SERVICES.COM"
        domainName = UIDNAHookICU.encode(domainName)!
        blackHole(domainName)
    }

    /// Mark: - Multiple_Domains data
    /// Grabbed from Cloudflare top domains

    // [
    //     "лодочный-причал.рф",
    //     "мойассистент.рф",
    //     "мвд.рф",
    //     "高速下载.com",
    //     "全球下载.com",
    //     "赛格gps.公司",
    //     "šijanec.eu",
    //     "lepší.tv",
    //     "نسوانجي.net",
    //     "ångströ.com",
    //     "求人ボックス.com",
    //     "т.website",
    //     "szukamksiążki.pl",
    // ]
    let multipleDomains: [13 of [UInt8]] = [
        [
            0xD0, 0xBB, 0xD0, 0xBE, 0xD0, 0xB4, 0xD0, 0xBE,
            0xD1, 0x87, 0xD0, 0xBD, 0xD1, 0x8B, 0xD0, 0xB9,
            0x2D, 0xD0, 0xBF, 0xD1, 0x80, 0xD0, 0xB8, 0xD1,
            0x87, 0xD0, 0xB0, 0xD0, 0xBB, 0x2E, 0xD1, 0x80,
            0xD1, 0x84,
        ],
        [
            0xD0, 0xBC, 0xD0, 0xBE, 0xD0, 0xB9, 0xD0, 0xB0,
            0xD1, 0x81, 0xD1, 0x81, 0xD0, 0xB8, 0xD1, 0x81,
            0xD1, 0x82, 0xD0, 0xB5, 0xD0, 0xBD, 0xD1, 0x82,
            0x2E, 0xD1, 0x80, 0xD1, 0x84,
        ],
        [
            0xD0, 0xBC, 0xD0, 0xB2, 0xD0, 0xB4, 0x2E, 0xD1,
            0x80, 0xD1, 0x84,
        ],
        [
            0xE9, 0xAB, 0x98, 0xE9, 0x80, 0x9F, 0xE4, 0xB8,
            0x8B, 0xE8, 0xBD, 0xBD, 0x2E, 0x63, 0x6F, 0x6D,
        ],
        [
            0xE5, 0x85, 0xA8, 0xE7, 0x90, 0x83, 0xE4, 0xB8,
            0x8B, 0xE8, 0xBD, 0xBD, 0x2E, 0x63, 0x6F, 0x6D,
        ],
        [
            0xE8, 0xB5, 0x9B, 0xE6, 0xA0, 0xBC, 0x67, 0x70,
            0x73, 0x2E, 0xE5, 0x85, 0xAC, 0xE5, 0x8F, 0xB8,
        ],
        [
            0xC5, 0xA1, 0x69, 0x6A, 0x61, 0x6E, 0x65, 0x63,
            0x2E, 0x65, 0x75,
        ],
        [
            0x6C, 0x65, 0x70, 0xC5, 0xA1, 0xC3, 0xAD, 0x2E,
            0x74, 0x76,
        ],
        [
            0xD9, 0x86, 0xD8, 0xB3, 0xD9, 0x88, 0xD8, 0xA7,
            0xD9, 0x86, 0xD8, 0xAC, 0xD9, 0x8A, 0x2E, 0x6E,
            0x65, 0x74,
        ],
        [
            0xC3, 0xA5, 0x6E, 0x67, 0x73, 0x74, 0x72, 0xC3,
            0xB6, 0x2E, 0x63, 0x6F, 0x6D,
        ],
        [
            0xE6, 0xB1, 0x82, 0xE4, 0xBA, 0xBA, 0xE3, 0x83,
            0x9C, 0xE3, 0x83, 0x83, 0xE3, 0x82, 0xAF, 0xE3,
            0x82, 0xB9, 0x2E, 0x63, 0x6F, 0x6D,
        ],
        [
            0xD1, 0x82, 0x2E, 0x77, 0x65, 0x62, 0x73, 0x69,
            0x74, 0x65,
        ],
        [
            0x73, 0x7A, 0x75, 0x6B, 0x61, 0x6D, 0x6B, 0x73,
            0x69, 0xC4, 0x85, 0xC5, 0xBC, 0x6B, 0x69, 0x2E,
            0x70, 0x6C,
        ],
    ]

    let multipleDomainsICU: [13 of String] = [
        "лодочный-причал.рф",
        "мойассистент.рф",
        "мвд.рф",
        "高速下载.com",
        "全球下载.com",
        "赛格gps.公司",
        "šijanec.eu",
        "lepší.tv",
        "نسوانجي.net",
        "ångströ.com",
        "求人ボックス.com",
        "т.website",
        "szukamksiążki.pl",
    ]

    for (namePrefix, idnaConfig) in nameAndConfigs {
        /// Mark: - öob.se
        /// Grabbed from Cloudflare top 1M domains

        Benchmark(
            "To_ASCII_\(namePrefix)_öob_dot_se_CPU_300K",
            configuration: .init(
                metrics: [.cpuUser],
                warmupIterations: 15,
                maxIterations: 1000,
            )
        ) { benchmark in
            for _ in 0..<300_000 {
                var domainName = "öob.dot"
                domainName = try! idnaConfig.toASCII(domainName: domainName)
                blackHole(domainName)
            }
        }

        Benchmark(
            "To_ASCII_\(namePrefix)_öob_dot_se_Malloc",
            configuration: .init(
                metrics: [.mallocCountTotal],
                warmupIterations: 1,
                maxIterations: 10,
            )
        ) { benchmark in
            var domainName = "öob.dot"
            domainName = try! idnaConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }

        Benchmark(
            "To_ASCII_\(namePrefix)_öob_dot_se_Instructions",
            configuration: .init(
                metrics: [.instructions],
                warmupIterations: 10,
                maxIterations: 10,
            )
        ) { benchmark in
            var domainName = "öob.dot"
            domainName = try! idnaConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }

        if namePrefix.lowercased() == "lax" {
            Benchmark(
                "To_ASCII_\(namePrefix)_öob_dot_se_CPU_300K_ICU",
                configuration: .init(
                    metrics: [.cpuUser],
                    warmupIterations: 15,
                    maxIterations: 1000,
                )
            ) { benchmark in
                for _ in 0..<300_000 {
                    var domainName = "öob.dot"
                    domainName = UIDNAHookICU.encode(domainName)!
                    blackHole(domainName)
                }
            }

            Benchmark(
                "To_ASCII_\(namePrefix)_öob_dot_se_Malloc_ICU",
                configuration: .init(
                    metrics: [.mallocCountTotal],
                    warmupIterations: 1,
                    maxIterations: 10,
                )
            ) { benchmark in
                var domainName = "öob.dot"
                domainName = UIDNAHookICU.encode(domainName)!
                blackHole(domainName)
            }

            Benchmark(
                "To_ASCII_\(namePrefix)_öob_dot_se_Instructions_ICU",
                configuration: .init(
                    metrics: [.instructions],
                    warmupIterations: 10,
                    maxIterations: 10,
                )
            ) { benchmark in
                var domainName = "öob.dot"
                domainName = UIDNAHookICU.encode(domainName)!
                blackHole(domainName)
            }
        }

        /// Mark: - 生命之花.中国
        /// Grabbed from Cloudflare top 100K domains

        Benchmark(
            "To_ASCII_\(namePrefix)_生命之花_dot_中国_CPU_200K",
            configuration: .init(
                metrics: [.cpuUser],
                warmupIterations: 15,
                maxIterations: 1000,
            )
        ) { benchmark in
            for _ in 0..<200_000 {
                var domainName = "生命之花.中国"
                domainName = try! idnaConfig.toASCII(domainName: domainName)
                blackHole(domainName)
            }
        }

        Benchmark(
            "To_ASCII_\(namePrefix)_生命之花_dot_中国_Malloc",
            configuration: .init(
                metrics: [.mallocCountTotal],
                warmupIterations: 1,
                maxIterations: 10,
            )
        ) { benchmark in
            var domainName = "生命之花.中国"
            domainName = try! idnaConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }

        Benchmark(
            "To_ASCII_\(namePrefix)_生命之花_dot_中国_Instructions",
            configuration: .init(
                metrics: [.instructions],
                warmupIterations: 10,
                maxIterations: 10,
            )
        ) { benchmark in
            var domainName = "生命之花.中国"
            domainName = try! idnaConfig.toASCII(domainName: domainName)
            blackHole(domainName)
        }

        if namePrefix.lowercased() == "lax" {
            Benchmark(
                "To_ASCII_\(namePrefix)_生命之花_dot_中国_CPU_200K_ICU",
                configuration: .init(
                    metrics: [.cpuUser],
                    warmupIterations: 15,
                    maxIterations: 1000,
                )
            ) { benchmark in
                for _ in 0..<200_000 {
                    var domainName = "生命之花.中国"
                    domainName = UIDNAHookICU.encode(domainName)!
                    blackHole(domainName)
                }
            }

            Benchmark(
                "To_ASCII_\(namePrefix)_生命之花_dot_中国_Malloc_ICU",
                configuration: .init(
                    metrics: [.mallocCountTotal],
                    warmupIterations: 1,
                    maxIterations: 10,
                )
            ) { benchmark in
                var domainName = "生命之花.中国"
                domainName = UIDNAHookICU.encode(domainName)!
                blackHole(domainName)
            }

            Benchmark(
                "To_ASCII_\(namePrefix)_生命之花_dot_中国_Instructions_ICU",
                configuration: .init(
                    metrics: [.instructions],
                    warmupIterations: 10,
                    maxIterations: 10,
                )
            ) { benchmark in
                var domainName = "生命之花.中国"
                domainName = UIDNAHookICU.encode(domainName)!
                blackHole(domainName)
            }
        }

        /// Mark: - Multiple_Domains

        Benchmark(
            "To_ASCII_\(namePrefix)_Multiple_Domains_CPU_200K",
            configuration: .init(
                metrics: [.cpuUser],
                warmupIterations: 15,
                maxIterations: 1000,
            )
        ) { benchmark in
            var rng = FastRNG()
            for _ in 0..<200_000 {
                let idx = Int(rng.next() % UInt64(multipleDomains.count))
                let result = try! idnaConfig.toASCII(
                    _uncheckedAssumingValidUTF8: multipleDomains[idx].span
                )
                let domainName = unsafe result.collect().unsafelyUnwrapped
                blackHole(domainName)
            }
        }

        Benchmark(
            "To_ASCII_\(namePrefix)_Multiple_Domains_Malloc",
            configuration: .init(
                metrics: [.mallocCountTotal],
                warmupIterations: 1,
                maxIterations: 10,
            )
        ) { benchmark in
            for idx in multipleDomains.indices {
                let result = try! idnaConfig.toASCII(
                    _uncheckedAssumingValidUTF8: multipleDomains[idx].span
                )
                let domainName = unsafe result.collect().unsafelyUnwrapped
                blackHole(domainName)
            }
        }

        Benchmark(
            "To_ASCII_\(namePrefix)_Multiple_Domains_Instructions",
            configuration: .init(
                metrics: [.instructions],
                warmupIterations: 10,
                maxIterations: 10,
            )
        ) { benchmark in
            for idx in multipleDomains.indices {
                let result = try! idnaConfig.toASCII(
                    _uncheckedAssumingValidUTF8: multipleDomains[idx].span
                )
                let domainName = unsafe result.collect().unsafelyUnwrapped
                blackHole(domainName)
            }
        }

        if namePrefix.lowercased() == "lax" {
            Benchmark(
                "To_ASCII_\(namePrefix)_Multiple_Domains_CPU_200K_ICU",
                configuration: .init(
                    metrics: [.cpuUser],
                    warmupIterations: 15,
                    maxIterations: 1000,
                )
            ) { benchmark in
                var rng = FastRNG()
                for _ in 0..<200_000 {
                    let idx = Int(rng.next() % UInt64(multipleDomainsICU.count))
                    let domainName = UIDNAHookICU.encode(multipleDomainsICU[idx])!
                    blackHole(domainName)
                }
            }

            Benchmark(
                "To_ASCII_\(namePrefix)_Multiple_Domains_Malloc_ICU",
                configuration: .init(
                    metrics: [.mallocCountTotal],
                    warmupIterations: 1,
                    maxIterations: 10,
                )
            ) { benchmark in
                for idx in multipleDomainsICU.indices {
                    let domainName = UIDNAHookICU.encode(multipleDomainsICU[idx])!
                    blackHole(domainName)
                }
            }

            Benchmark(
                "To_ASCII_\(namePrefix)_Multiple_Domains_Instructions_ICU",
                configuration: .init(
                    metrics: [.instructions],
                    warmupIterations: 10,
                    maxIterations: 10,
                )
            ) { benchmark in
                for idx in multipleDomainsICU.indices {
                    let domainName = UIDNAHookICU.encode(multipleDomainsICU[idx])!
                    blackHole(domainName)
                }
            }
        }
    }
}
