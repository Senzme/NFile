allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.configureEach {
        exclude(group = "com.google.android.play")
        exclude(group = "com.google.android.play", module = "core")
        exclude(group = "com.google.android.play", module = "core-common")
        exclude(group = "com.google.android.play", module = "review")
        exclude(group = "com.google.android.play", module = "app-update")
        exclude(group = "com.google.android.play", module = "feature-delivery")
        exclude(group = "com.google.android.play", module = "integrity")
        exclude(group = "com.google.android.play", module = "asset-delivery")
        
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.google.android.play:core")).using(module("androidx.annotation:annotation:1.9.1"))
            substitute(module("com.google.android.play:core-common")).using(module("androidx.annotation:annotation:1.9.1"))
            substitute(module("com.google.android.play:review")).using(module("androidx.annotation:annotation:1.9.1"))
            substitute(module("com.google.android.play:app-update")).using(module("androidx.annotation:annotation:1.9.1"))
            substitute(module("com.google.android.play:feature-delivery")).using(module("androidx.annotation:annotation:1.9.1"))
            substitute(module("com.google.android.play:integrity")).using(module("androidx.annotation:annotation:1.9.1"))
            substitute(module("com.google.android.play:asset-delivery")).using(module("androidx.annotation:annotation:1.9.1"))
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (project.name != "app") {
        project.afterEvaluate {
            project.plugins.withId("com.android.library") {
                project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                    compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                }
            }
            project.tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "17"
                targetCompatibility = "17"
            }
            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
