import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

public class TestAudio {
    public static void main(String[] args) throws Exception {
        int sr = 48000;
        int secs = 4;
        double freq = 440.0;
        int fr = 0;

        int minBuf = AudioTrack.getMinBufferSize(sr,
                AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT);
        System.out.println("minBuf=" + minBuf);

        AudioTrack track;
        if (android.os.Build.VERSION.SDK_INT >= 23) {
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build();
            AudioFormat fmt = new AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sr)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build();
            track = new AudioTrack.Builder()
                    .setAudioAttributes(attrs)
                    .setAudioFormat(fmt)
                    .setBufferSizeInBytes(Math.max(minBuf * 4, 96000))
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build();
        } else {
            track = new AudioTrack(AudioManager.STREAM_MUSIC, sr,
                    AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT,
                    Math.max(minBuf * 4, 96000), AudioTrack.MODE_STREAM);
        }

        System.out.println("state=" + track.getState());
        track.play();
        System.out.println("playState=" + track.getPlayState());

        int frames = sr / 10;
        short[] buf = new short[frames * 2];
        long total = 0;
        long end = System.currentTimeMillis() + secs * 1000L;
        while (System.currentTimeMillis() < end) {
            for (int i = 0; i < frames; i++) {
                double ph = 2.0 * Math.PI * freq * ((total + i) % sr) / sr;
                short v = (short) (12000 * Math.sin(ph));
                buf[2 * i] = v;
                buf[2 * i + 1] = v;
            }
            int w = track.write(buf, 0, buf.length);
            if (w < 0) {
                System.out.println("write error=" + w);
                break;
            }
            total += frames;
        }
        track.stop();
        track.release();
        System.out.println("done frames=" + total);
    }
}
