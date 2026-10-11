import android.media.MediaCodec;
import android.media.MediaFormat;

public class TestCodec {
    static void log(String s) {
        System.err.println(s);
        System.err.flush();
    }

    public static void main(String[] args) {
        String[] types = {"audio/vorbis", "audio/mpeg", "audio/mp4a-latm", "audio/opus", "audio/raw", "audio/flac"};
        for (String type : types) {
            MediaCodec c = null;
            try {
                c = MediaCodec.createDecoderByType(type);
                log(type + " -> " + c.getName());
                MediaFormat f = MediaFormat.createAudioFormat(type, 44100, 2);
                c.configure(f, null, null, 0);
                log("   configure ok");
                c.start();
                log("   start OK");
            } catch (Throwable t) {
                log("   FAIL " + type + ": " + t);
            } finally {
                if (c != null) {
                    try { c.stop(); } catch (Throwable ignore) {}
                    try { c.release(); } catch (Throwable ignore) {}
                }
            }
        }
    }
}
