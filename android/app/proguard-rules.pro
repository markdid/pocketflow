# WorkManager's Room database is instantiated by reflection during app startup.
# R8 must retain its no-argument constructor as well as the generated class.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
