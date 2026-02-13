// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer.platformview;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultLoadControl;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.plugins.videoplayer.ExoPlayerEventListener;
import io.flutter.plugins.videoplayer.VideoAsset;
import io.flutter.plugins.videoplayer.VideoPlayer;
import io.flutter.plugins.videoplayer.VideoPlayerCallbacks;
import io.flutter.plugins.videoplayer.VideoPlayerOptions;
import io.flutter.view.TextureRegistry.SurfaceProducer;

/**
 * A subclass of {@link VideoPlayer} that adds functionality related to platform view as a way of
 * displaying the video in the app.
 */
public class PlatformViewVideoPlayer extends VideoPlayer {
  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @VisibleForTesting
  public PlatformViewVideoPlayer(
      @NonNull VideoPlayerCallbacks events,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @NonNull ExoPlayerProvider exoPlayerProvider) {
    super(events, mediaItem, options, /* surfaceProducer */ null, exoPlayerProvider);
  }

  /**
   * Creates a platform view video player.
   *
   * @param context application context.
   * @param events event callbacks.
   * @param asset asset to play.
   * @param options options for playback.
   * @return a video player instance.
   */
  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @NonNull
  public static PlatformViewVideoPlayer create(
      @NonNull Context context,
      @NonNull VideoPlayerCallbacks events,
      @NonNull VideoAsset asset,
      @NonNull VideoPlayerOptions options) {
    return new PlatformViewVideoPlayer(
        events,
        asset.getMediaItem(),
        options,
        () -> {
          androidx.media3.exoplayer.trackselection.DefaultTrackSelector trackSelector =
              new androidx.media3.exoplayer.trackselection.DefaultTrackSelector(context);
          // 启用隧道播放：解码帧直通显示硬件，绕过 Flutter 合成（TV 专用，不支持时自动回退）
          trackSelector.setParameters(
              trackSelector.buildUponParameters()
                  .setTunnelingEnabled(true)
                  .build());

          // 自定义缓冲策略：更大缓冲减少卡顿（借鉴 BBLL 策略）
          DefaultLoadControl loadControl =
              new DefaultLoadControl.Builder()
                  .setBufferDurationsMs(
                      5000,   // minBufferMs：最少缓冲 5 秒
                      50000,  // maxBufferMs：最多缓冲 50 秒
                      2000,   // bufferForPlaybackMs：起播前缓冲 2 秒
                      4000)   // bufferForPlaybackAfterRebufferMs：重缓冲后 4 秒再播
                  .setPrioritizeTimeOverSizeThresholds(true)
                  .build();

          ExoPlayer exoPlayer =
              new ExoPlayer.Builder(context)
                  .setTrackSelector(trackSelector)
                  .setLoadControl(loadControl)
                  .setMediaSourceFactory(asset.getMediaSourceFactory(context))
                  .setVideoChangeFrameRateStrategy(
                      C.VIDEO_CHANGE_FRAME_RATE_STRATEGY_ONLY_IF_SEAMLESS)
                  .build();
          return exoPlayer;
        });
  }

  @NonNull
  @Override
  protected ExoPlayerEventListener createExoPlayerEventListener(
      @NonNull ExoPlayer exoPlayer, @Nullable SurfaceProducer surfaceProducer) {
    return new PlatformViewExoPlayerEventListener(exoPlayer, videoPlayerEvents);
  }
}
