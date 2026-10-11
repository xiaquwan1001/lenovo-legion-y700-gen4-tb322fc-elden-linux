/*
 * SensorFW.h — route C replacement for the SensorFW() data source of
 * waydroid-sensors (TASKS.md C4).
 *
 * Rationale: upstream waydroid-sensord gets its data from sensorfw over the
 * system D-Bus (com.nokia.SensorService). On this device sensorfw has no SSC
 * adaptor and the kernel IIO tree is empty, so upstream can only ever
 * register an empty HAL. This drop-in keeps the exact same class name and
 * method signatures as upstream SensorFW.h, so Sensors.cpp/service.cpp stay
 * byte-identical, but feeds the HAL from a simple UDP text protocol instead:
 *
 *   acc <x> <y> <z>   [ts]   acceleration, m/s^2
 *   gyr <x> <y> <z>   [ts]   gyroscope, rad/s
 *   mag <x> <y> <z>   [ts]   magnetic field, uT
 *   light <v>         [ts]   ambient light, lux
 *   prox <v>          [ts]   proximity distance, cm (0 = near)
 *
 * The producer is the already verified host-side scripts/eldroid-sensord.c
 * (--fake / --stdin), or a libssc relay. Source: Waydroid Project (GPL-3.0),
 * adapted. Copyright for the unchanged parts remains with the Waydroid Project.
 */

#ifndef SENSORHW_H_
#define SENSORHW_H_

#include <stdint.h>
#include <pthread.h>

#include <vector>

namespace waydroid {

#define MAX_NUM_SENSORS 11

#define SUPPORTED_SENSORS  ((1<<MAX_NUM_SENSORS)-1)

#define  ID_BASE                        0
#define  ID_ACCELEROMETER               (ID_BASE+0)
#define  ID_GYROSCOPE                   (ID_BASE+1)
#define  ID_HUMIDITY                    (ID_BASE+2)
#define  ID_LIGHT                       (ID_BASE+3)
#define  ID_MAGNETIC_FIELD              (ID_BASE+4)
#define  ID_MAGNETIC_FIELD_UNCALIBRATED (ID_BASE+5)
#define  ID_DEVICE_ORIENTATION          (ID_BASE+6)
#define  ID_PRESSURE                    (ID_BASE+7)
#define  ID_PROXIMITY                   (ID_BASE+8)
#define  ID_STEPCOUNTER                 (ID_BASE+9)
#define  ID_TEMPERATURE                 (ID_BASE+10)

#define  SENSORS_ACCELEROMETER                (1 << ID_ACCELEROMETER)
#define  SENSORS_GYROSCOPE                    (1 << ID_GYROSCOPE)
#define  SENSORS_HUMIDITY                     (1 << ID_HUMIDITY)
#define  SENSORS_LIGHT                        (1 << ID_LIGHT)
#define  SENSORS_MAGNETIC_FIELD               (1 << ID_MAGNETIC_FIELD)
#define  SENSORS_MAGNETIC_FIELD_UNCALIBRATED  (1 << ID_MAGNETIC_FIELD_UNCALIBRATED)
#define  SENSORS_DEVICE_ORIENTATION           (1 << ID_DEVICE_ORIENTATION)
#define  SENSORS_PRESSURE                     (1 << ID_PRESSURE)
#define  SENSORS_PROXIMITY                    (1 << ID_PROXIMITY)
#define  SENSORS_STEPCOUNTER                  (1 << ID_STEPCOUNTER)
#define  SENSORS_TEMPERATURE                  (1 << ID_TEMPERATURE)

#define  ID_CHECK(x)  ((unsigned)((x) - ID_BASE) < MAX_NUM_SENSORS)

#define  SENSORS_LIST  \
    SENSOR_(ACCELEROMETER,"accelerometer") \
    SENSOR_(GYROSCOPE,"gyroscope") \
    SENSOR_(HUMIDITY, "humidity") \
    SENSOR_(LIGHT, "light") \
    SENSOR_(MAGNETIC_FIELD,"magnetic-field") \
    SENSOR_(MAGNETIC_FIELD_UNCALIBRATED,"magnetic-field-uncalibrated") \
    SENSOR_(DEVICE_ORIENTATION,"device-orientation") \
    SENSOR_(PRESSURE, "pressure") \
    SENSOR_(PROXIMITY,"proximity") \
    SENSOR_(STEPCOUNTER, "stepcounter") \
    SENSOR_(TEMPERATURE,"temperature")

static const struct {
    const char*  name;
    int          id; } _sensorIds[MAX_NUM_SENSORS] =
{
#define SENSOR_(x,y)  { y, ID_##x },
    SENSORS_LIST
#undef  SENSOR_
};

static const char* _SensorIdToName(int id) {
    int nn;
    for (nn = 0; nn < MAX_NUM_SENSORS; nn++)
        if (id == _sensorIds[nn].id)
            return _sensorIds[nn].name;
    return "<UNKNOWN>";
}

typedef void (*sensor_event_cb_t)(void *userdata, int id);

struct SensorFW;
void *udp_thread_main(void *arg);

typedef struct {
    bool     available;
    bool     enabled;
    int64_t  ts;       /* boottime ns of last update */
    double   v[3];     /* generic payload (m/s^2, rad/s, uT or scalar) */
    bool     is_near;  /* for proximity */
} UdpSensorValue;

struct SensorFW {
    SensorFW();
    ~SensorFW();

    void RegisterSensors(sensor_event_cb_t cb, void *userdata);
    bool IsSensorAvailable(int id);
    bool IsSensorEventEnable(int id);
    int EnableSensorEvents(int id);
    int DisableSensorEvents(int id);

    int GetAccelerometerEvent(uint64_t *ts, int *x, int *y, int *z);
    int GetGyroscopeEvent(uint64_t *ts, int *x, int *y, int *z);
    int GetHumidityEvent(uint64_t *ts, unsigned *value);
    int GetLightEvent(uint64_t *ts, unsigned *value);
    int GetMagnetometerEvent(uint64_t *ts, int *x, int *y, int *z,
        int *rx, int *ry, int *rz, int* level);
    int GetOrientationEvent(uint64_t *ts, int *degree);
    int GetPressureEvent(uint64_t *ts, unsigned *value);
    int GetProximityEvent(uint64_t *ts, unsigned *value, bool *isNear);
    int GetStepcounterEvent(uint64_t *ts, unsigned *value);
    int GetTemperatureEvent(uint64_t *ts, unsigned *value);

private:
    friend void *udp_thread_main(void *arg);
    void handle_line(const char *line);

    sensor_event_cb_t mCb;
    void             *mUserdata;
    uint32_t          mAvailable;   /* which sensors we advertise */
    UdpSensorValue    mValues[MAX_NUM_SENSORS];
    pthread_t         mThread;
    volatile int      mStop;
    int               mFd;
};

}  // namespace waydroid

#endif  // SENSORHW_H_
