// 注意：请先从 https://github.com/OrangeCloud-SDK-IM/orangecloud-im-android 下载 AAR
// 放入本项目 libs/ 目录后即可编译
plugins {
    kotlin("jvm") version "1.9.22"
    application
}

group = "com.orangecloud"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation(files("libs/orangecloud-im-client-release.aar"))
    implementation("com.microsoft.signalr:signalr:8.0.0")
    implementation("org.slf4j:slf4j-simple:2.0.9")
}

application {
    mainClass.set("com.orangecloud.demo.MainKt")
}
