import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;

public class TestRecord {
    static void log(String s) {
        System.err.println(s);
        System.err.flush();
    }

    public static void main(String[] args) {
        int sr = 48000;
        int secs = args.length > 0 ? Integer.parseInt(args[0]) : 5;
        try {
            int min = AudioRecord.getMinBufferSize(sr,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            log("minBuf=" + min);
            int bufBytes = Math.max(min, sr); // >= 1s
            AudioRecord rec = new AudioRecord(MediaRecorder.AudioSource.MIC, sr,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufBytes);
            log("state=" + rec.getState());
            rec.startRecording();
            log("recordingState=" + rec.getRecordingState());

            short[] buf = new short[2400];
            long sum = 0, n = 0;
            int peak = 0;
            long end = System.currentTimeMillis() + secs * 1000L;
            while (System.currentTimeMillis() < end) {
                int r = rec.read(buf, 0, buf.length);
                if (r <= 0) { log("read err=" + r); break; }
                for (int i = 0; i < r; i++) {
                    int v = buf[i];
                    sum += (long) v * v;
                    if (Math.abs(v) > peak) peak = Math.abs(v);
                }
                n += r;
            }
            rec.stop();
            rec.release();
            double rms = n > 0 ? Math.sqrt((double) sum / n) : 0;
            log("samples=" + n + " rms=" + String.format("%.1f", rms) + " peak=" + peak);
        } catch (Throwable t) {
            log("EXCEPTION " + t);
            t.printStackTrace();
        }
    }
}
