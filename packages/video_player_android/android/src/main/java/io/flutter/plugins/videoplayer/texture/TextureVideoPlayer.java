// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer.texture;

import android.content.Context;
import android.content.SharedPreferences;
import android.view.Surface;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RestrictTo;
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
 * A subclass of {@link VideoPlayer} that adds functionality related to texture view as a way of
 * displaying the video in the app.
 *
 * <p>It manages the lifecycle of the texture and ensures that the video is properly displayed on
 * the texture.
 */
public final class TextureVideoPlayer extends VideoPlayer implements SurfaceProducer.Callback {
  // True when the ExoPlayer instance has a null surface.
  private boolean needsSurface = true;
  /**
   * Creates a texture video player.
   *
   * @param context application context.
   * @param events event callbacks.
   * @param surfaceProducer produces a texture to render to.
   * @param asset asset to play.
   * @param options options for playback.
   * @return a video player instance.
   */
  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @NonNull
  public static TextureVideoPlayer create(
      @NonNull Context context,
      @NonNull VideoPlayerCallbacks events,
      @NonNull SurfaceProducer surfaceProducer,
      @NonNull VideoAsset asset,
      @NonNull VideoPlayerOptions options) {
    return new TextureVideoPlayer(
        events,
        surfaceProducer,
        asset.getMediaItem(),
        options,
        () -> {
          // 读取 Flutter 设置中的播放性能模式（0=高,1=中,2=低）
          final SharedPreferences prefs =
              context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
          final int perfMode = (int) prefs.getLong("flutter.playback_performance_mode", 1L);

          int minBufferMs = 3000;
          int maxBufferMs = 30000;
          int bufferForPlaybackMs = 1500;
          int bufferForPlaybackAfterRebufferMs = 3000;
          int backBufferDurationMs = 15000;
          if (perfMode == 0) {
            minBufferMs = 5000;
            maxBufferMs = 50000;
            bufferForPlaybackMs = 2000;
            bufferForPlaybackAfterRebufferMs = 4000;
            backBufferDurationMs = 30000;
          } else if (perfMode == 2) {
            minBufferMs = 2000;
            maxBufferMs = 15000;
            bufferForPlaybackMs = 1000;
            bufferForPlaybackAfterRebufferMs = 2000;
            backBufferDurationMs = 0;
          }

          final boolean tunnelMode = prefs.getBoolean("flutter.tunnel_mode_enabled", true);

          androidx.media3.exoplayer.trackselection.DefaultTrackSelector trackSelector =
              new androidx.media3.exoplayer.trackselection.DefaultTrackSelector(context);
          trackSelector.setParameters(
              trackSelector.buildUponParameters()
                  .setTunnelingEnabled(tunnelMode)
                  .build());

          // 自定义缓冲策略：更大缓冲减少卡顿
          // - 增大 back buffer 保留已播放内容，防止回退时重新加载
          // - 保持 back buffer 可用于回退操作
          DefaultLoadControl loadControl =
              new DefaultLoadControl.Builder()
                  .setBufferDurationsMs(
                      minBufferMs,
                      maxBufferMs,
                      bufferForPlaybackMs,
                      bufferForPlaybackAfterRebufferMs)
                  .setBackBuffer(
                      backBufferDurationMs,
                      true)   // retainBackBufferFromKeyframe：从关键帧保留
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

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @VisibleForTesting
  public TextureVideoPlayer(
      @NonNull VideoPlayerCallbacks events,
      @NonNull SurfaceProducer surfaceProducer,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @NonNull ExoPlayerProvider exoPlayerProvider) {
    super(events, mediaItem, options, surfaceProducer, exoPlayerProvider);

    surfaceProducer.setCallback(this);

    Surface surface = surfaceProducer.getSurface();
    this.exoPlayer.setVideoSurface(surface);
    needsSurface = surface == null;
  }

  @NonNull
  @Override
  protected ExoPlayerEventListener createExoPlayerEventListener(
      @NonNull ExoPlayer exoPlayer, @Nullable SurfaceProducer surfaceProducer) {
    if (surfaceProducer == null) {
      throw new IllegalArgumentException(
          "surfaceProducer cannot be null to create an ExoPlayerEventListener for TextureVideoPlayer.");
    }
    boolean surfaceProducerHandlesCropAndRotation = surfaceProducer.handlesCropAndRotation();
    return new TextureExoPlayerEventListener(
        exoPlayer, videoPlayerEvents, surfaceProducerHandlesCropAndRotation);
  }

  @RestrictTo(RestrictTo.Scope.LIBRARY)
  public void onSurfaceAvailable() {
    if (needsSurface) {
      // TextureVideoPlayer must always set a surfaceProducer.
      assert surfaceProducer != null;
      exoPlayer.setVideoSurface(surfaceProducer.getSurface());
      needsSurface = false;
    }
  }

  @RestrictTo(RestrictTo.Scope.LIBRARY)
  public void onSurfaceCleanup() {
    exoPlayer.setVideoSurface(null);
    needsSurface = true;
  }

  public void dispose() {
    // Super must be called first to ensure the player is released before the surface.
    super.dispose();

    // TextureVideoPlayer must always set a surfaceProducer.
    assert surfaceProducer != null;
    surfaceProducer.release();
  }
}
