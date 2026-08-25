allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// 플러그인마다 자기 build.gradle에 적어둔 Java/Kotlin 타깃이 제각각이라
// (another_telephony는 Kotlin 1.8인데 Java는 11, 카카오 SDK는 17) 한 모듈 안에서
// 두 값이 어긋나면 컴파일이 멈춘다. 앱과 같은 17로 함께 맞춰 준다.
// 플러그인들이 Built-in Kotlin으로 옮겨오면 지워도 된다.
// ※ 아래 evaluationDependsOn(":app")이 평가를 끝내버리므로 반드시 그보다 먼저 건다.
subprojects {
    afterEvaluate {
        val android =
            extensions.findByType<com.android.build.gradle.LibraryExtension>()
                ?: return@afterEvaluate
        android.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
