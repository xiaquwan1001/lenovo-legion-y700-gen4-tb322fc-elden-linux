/*
 * SensorFW.cpp — UDP-backed data source for waydroid-sensord (route C, C4).
 *
 * Drop-in for upstream SensorFW.cpp: same class, same method signatures, but
 * no sensorfw/libssc/Qt dependency. It listens on a UDP port (default 52012,
 * override with WAYDROID_SENSORD_PORT) for the human-readable text protocol
 * produced by scripts/eldroid-sensord.c and pushes events into the caller's
 * sensor_event_cb_t, exactly like upstream's D-Bus callbacks do.
 *
 * GPL-3.0-or-later. The unchanged ABI/interface is the Waydroid Project's.
 */

#include "SensorFW.h"

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>

#define DEFAULT_PORT 52012

namespace waydroid {

static bool dbg_enabled(void) { static int d = -1; if (d < 0) d = getenv("SENSORD_DEBUG") ? 1 : 0; return d; }

static int64_t now_boottime_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_BOOTTIME, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* Which sensors we advertise to the framework. The real source can send all
 * of these (eldroid-sensord --fake does; SSC relay sends acc/light/prox/mag). */
#define ROUTE_C_SENSORS (SENSORS_ACCELEROMETER | SENSORS_GYROSCOPE | \
                         SENSORS_MAGNETIC_FIELD | SENSORS_MAGNETIC_FIELD_UNCALIBRATED | \
                         SENSORS_LIGHT | SENSORS_PROXIMITY)

void *udp_thread_main(void *arg);

SensorFW::SensorFW()
    : mCb(nullptr), mUserdata(nullptr), mAvailable(ROUTE_C_SENSORS),
      mThread(0), mStop(0), mFd(-1)
{
    memset(mValues, 0, sizeof(mValues));

    int port = DEFAULT_PORT;
    const char *p = getenv("WAYDROID_SENSORD_PORT");
    if (p && *p)
        port = atoi(p);

    mFd = socket(AF_INET, SOCK_DGRAM, 0);
    if (mFd < 0) {
        fprintf(stderr, "[sensord-udp] socket failed: %s\n", strerror(errno));
        return;
    }
    int one = 1;
    setsockopt(mFd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);
    if (bind(mFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        fprintf(stderr, "[sensord-udp] bind :%d failed: %s\n", port, strerror(errno));
        close(mFd);
        mFd = -1;
        return;
    }

    if (pthread_create(&mThread, NULL, udp_thread_main, this) != 0) {
        fprintf(stderr, "[sensord-udp] pthread_create failed\n");
        close(mFd);
        mFd = -1;
        return;
    }
    fprintf(stderr, "[sensord-udp] listening on udp/0.0.0.0:%d\n", port);
}

SensorFW::~SensorFW()
{
    mStop = 1;
    if (mFd >= 0)
        shutdown(mFd, SHUT_RDWR);
    if (mThread)
        pthread_join(mThread, NULL);
    if (mFd >= 0)
        close(mFd);
}

void SensorFW::RegisterSensors(sensor_event_cb_t cb, void *userdata)
{
    mCb = cb;
    mUserdata = userdata;
    for (int i = 0; i < MAX_NUM_SENSORS; i++)
        mValues[i].available = (mAvailable >> i) & 1U;
}

bool SensorFW::IsSensorAvailable(int id)
{
    if (!ID_CHECK(id))
        return false;
    return (mAvailable >> id) & 1U;
}

bool SensorFW::IsSensorEventEnable(int id)
{
    if (!ID_CHECK(id))
        return false;
    return mValues[id].enabled;
}

int SensorFW::EnableSensorEvents(int id)
{
    if (!ID_CHECK(id))
        return -1;
    mValues[id].enabled = true;
    if (dbg_enabled()) fprintf(stderr, "[sensord-udp] ENABLE id=%d (%s)\n", id, _SensorIdToName(id));
    return 0;
}

int SensorFW::DisableSensorEvents(int id)
{
    if (!ID_CHECK(id))
        return -1;
    mValues[id].enabled = false;
    if (dbg_enabled()) fprintf(stderr, "[sensord-udp] DISABLE id=%d (%s)\n", id, _SensorIdToName(id));
    return 0;
}

/* ---- event getters: return stored values in upstream's units ---- */

int SensorFW::GetAccelerometerEvent(uint64_t *ts, int *x, int *y, int *z)
{
    if (!mValues[ID_ACCELEROMETER].available) return -1;
    *ts = (uint64_t)mValues[ID_ACCELEROMETER].ts;
    *x = (int)lround(mValues[ID_ACCELEROMETER].v[0] * 100.0);
    *y = (int)lround(mValues[ID_ACCELEROMETER].v[1] * 100.0);
    *z = (int)lround(mValues[ID_ACCELEROMETER].v[2] * 100.0);
    return 0;
}

int SensorFW::GetGyroscopeEvent(uint64_t *ts, int *x, int *y, int *z)
{
    if (!mValues[ID_GYROSCOPE].available) return -1;
    *ts = (uint64_t)mValues[ID_GYROSCOPE].ts;
    *x = (int)lround(mValues[ID_GYROSCOPE].v[0] * 1000.0);
    *y = (int)lround(mValues[ID_GYROSCOPE].v[1] * 1000.0);
    *z = (int)lround(mValues[ID_GYROSCOPE].v[2] * 1000.0);
    return 0;
}

int SensorFW::GetHumidityEvent(uint64_t *ts, unsigned *value)
{
    if (!mValues[ID_HUMIDITY].available) return -1;
    *ts = (uint64_t)mValues[ID_HUMIDITY].ts;
    *value = (unsigned)lround(mValues[ID_HUMIDITY].v[0]);
    return 0;
}

int SensorFW::GetLightEvent(uint64_t *ts, unsigned *value)
{
    if (!mValues[ID_LIGHT].available) return -1;
    *ts = (uint64_t)mValues[ID_LIGHT].ts;
    *value = (unsigned)lround(mValues[ID_LIGHT].v[0]);
    return 0;
}

int SensorFW::GetMagnetometerEvent(uint64_t *ts, int *x, int *y, int *z,
    int *rx, int *ry, int *rz, int *level)
{
    if (!mValues[ID_MAGNETIC_FIELD].available) return -1;
    *ts = (uint64_t)mValues[ID_MAGNETIC_FIELD].ts;
    *x = (int)lround(mValues[ID_MAGNETIC_FIELD].v[0]);
    *y = (int)lround(mValues[ID_MAGNETIC_FIELD].v[1]);
    *z = (int)lround(mValues[ID_MAGNETIC_FIELD].v[2]);
    /* uncalibrated = raw, bias 0 */
    *rx = *x; *ry = *y; *rz = *z;
    if (level) *level = 3;
    return 0;
}

int SensorFW::GetOrientationEvent(uint64_t *ts, int *degree)
{
    if (!mValues[ID_DEVICE_ORIENTATION].available) return -1;
    *ts = (uint64_t)mValues[ID_DEVICE_ORIENTATION].ts;
    *degree = (int)lround(mValues[ID_DEVICE_ORIENTATION].v[0]);
    return 0;
}

int SensorFW::GetPressureEvent(uint64_t *ts, unsigned *value)
{
    if (!mValues[ID_PRESSURE].available) return -1;
    *ts = (uint64_t)mValues[ID_PRESSURE].ts;
    *value = (unsigned)lround(mValues[ID_PRESSURE].v[0]);
    return 0;
}

int SensorFW::GetProximityEvent(uint64_t *ts, unsigned *value, bool *isNear)
{
    if (!mValues[ID_PROXIMITY].available) return -1;
    *ts = (uint64_t)mValues[ID_PROXIMITY].ts;
    *value = (unsigned)lround(mValues[ID_PROXIMITY].v[0]);
    *isNear = mValues[ID_PROXIMITY].is_near;
    return 0;
}

int SensorFW::GetStepcounterEvent(uint64_t *ts, unsigned *value)
{
    if (!mValues[ID_STEPCOUNTER].available) return -1;
    *ts = (uint64_t)mValues[ID_STEPCOUNTER].ts;
    *value = (unsigned)lround(mValues[ID_STEPCOUNTER].v[0]);
    return 0;
}

int SensorFW::GetTemperatureEvent(uint64_t *ts, unsigned *value)
{
    if (!mValues[ID_TEMPERATURE].available) return -1;
    *ts = (uint64_t)mValues[ID_TEMPERATURE].ts;
    *value = (unsigned)lround(mValues[ID_TEMPERATURE].v[0]);
    return 0;
}

/* ---- line parser + UDP reader ---- */

void SensorFW::handle_line(const char *line)
{
    char type[16] = {0};
    double a = 0, b = 0, c = 0;
    int n = sscanf(line, "%15s %lf %lf %lf", type, &a, &b, &c);
    if (n < 2)
        return;

    int64_t ts = now_boottime_ns();
    int id = -1;
    bool three = false;

    if (!strcmp(type, "acc") || !strcmp(type, "accel") || !strcmp(type, "accelerometer")) {
        id = ID_ACCELEROMETER; three = true;
    } else if (!strcmp(type, "gyr") || !strcmp(type, "gyro") || !strcmp(type, "gyroscope")) {
        id = ID_GYROSCOPE; three = true;
    } else if (!strcmp(type, "mag") || !strcmp(type, "magnetic")) {
        id = ID_MAGNETIC_FIELD; three = true;
    } else if (!strcmp(type, "light") || !strcmp(type, "lux")) {
        id = ID_LIGHT;
    } else if (!strcmp(type, "prox") || !strcmp(type, "proximity")) {
        id = ID_PROXIMITY;
    } else if (!strcmp(type, "ori") || !strcmp(type, "orientation")) {
        id = ID_DEVICE_ORIENTATION;
    } else if (!strcmp(type, "press") || !strcmp(type, "pressure")) {
        id = ID_PRESSURE;
    }

    if (id < 0 || !((mAvailable >> id) & 1U))
        return;

    mValues[id].ts = ts;
    mValues[id].v[0] = a;
    if (three) {
        mValues[id].v[1] = b;
        mValues[id].v[2] = c;
    } else if (!strcmp(type, "prox") || !strcmp(type, "proximity")) {
        mValues[id].is_near = (a < 3.0);
    }
    mValues[id].available = true;

    if (dbg_enabled()) { static unsigned n[11] = {0}; if ((n[id]++ % 100) == 0) fprintf(stderr, "[sensord-udp] rx id=%d enabled=%d line=%s\n", id, (int)mValues[id].enabled, line); }
    if (mValues[id].enabled && mCb)
        mCb(mUserdata, id);
}

void *udp_thread_main(void *arg)
{
    SensorFW *self = (SensorFW *)arg;
    char buf[512];

    while (1) {
        ssize_t r = recv(self->mFd, buf, sizeof(buf) - 1, 0);
        if (r == 0)
            break;
        if (r < 0) {
            if (errno == EINTR)
                continue;
            break; /* socket closed / shutdown */
        }
        buf[r] = '\0';
        /* The producer emits one line per datagram; tolerate multi-line too. */
        char *save = NULL;
        for (char *t = strtok_r(buf, "\n", &save); t; t = strtok_r(NULL, "\n", &save))
            self->handle_line(t);
    }
    return NULL;
}

}  // namespace waydroid
