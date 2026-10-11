import android.media.MediaCodecInfo;
import android.media.MediaCodecList;

public class ListCodecs {
    public static void main(String[] args) throws Exception {
        MediaCodecList list = new MediaCodecList(MediaCodecList.REGULAR_CODECS);
        MediaCodecInfo[] infos = list.getCodecInfos();
        System.out.println("total codecs=" + infos.length);
        for (MediaCodecInfo ci : infos) {
            if (ci.isEncoder()) continue;
            System.out.println("DEC " + ci.getName());
        }
    }
}
