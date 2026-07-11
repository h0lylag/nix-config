# Shared Discord and Vencord configuration for graphical hosts.
{
  programs.nixcord = {
    enable = true;
    user = "chris";

    discord = {
      branch = "stable";
      vencord.enable = true;
      openASAR.enable = true;
      krisp.enable = true;
    };

    config.plugins = {
      anonymiseFileNames = {
        enable = true;
        anonymiseByDefault = false;
      };
      betterSessions.enable = true;
      biggerStreamPreview.enable = true;
      callTimer.enable = true;
      clearUrls.enable = true;
      copyFileContents.enable = true;
      crashHandler.enable = true;
      expressionCloner.enable = true;
      fakeNitro = {
        enable = true;
        enableEmojiBypass = false;
        transformEmojis = false;
        enableStickerBypass = false;
        transformStickers = false;
      };
      fixImagesQuality.enable = true;
      fixSpotifyEmbeds.enable = true;
      fixYoutubeEmbeds.enable = true;
      forceOwnerCrown.enable = true;
      implicitRelationships.enable = true;
      memberCount.enable = true;
      messageLogger = {
        enable = true;
        ignoreSelf = true;
        ignoreChannels = "1521394427237765160";
      };
      mutualGroupDms.enable = true;
      noBlockedMessages.enable = true;
      noF1.enable = true;
      noOnboardingDelay.enable = true;
      noUnblockToJump.enable = true;
      permissionsViewer.enable = true;
      pinDms = {
        enable = true;
        userBasedCategoryList = {
          "262240479549063168" = [
            {
              id = "0ysnz2a2yfs";
              name = "Favs";
              color = 10070709;
              collapsed = false;
              channels = [ ];
            }
          ];
          "1027673699891028162" = [ ];
          "959553694846844949" = [ ];
        };
      };
      platformIndicators.enable = true;
      readAllNotificationsButton.enable = true;
      relationshipNotifier.enable = true;
      reverseImageSearch.enable = true;
      serverInfo.enable = true;
      serverListIndicators.enable = true;
      showConnections.enable = true;
      showHiddenChannels = {
        enable = true;
        showMode = 1;
      };
      showHiddenThings.enable = true;
      showMeYourName.enable = true;
      silentMessageToggle.persistState = "none";
      typingIndicator.enable = true;
      userVoiceShow.enable = true;
      validUser.enable = true;
      vcNarrator = {
        volume = 0.2533092292207243;
        latinOnly = true;
      };
      viewRaw.enable = true;
      youtubeAdblock.enable = true;
    };

    extraConfig.plugins = {
      fakeNitro.useHyperLinks = false;
      noBlockedMessages = {
        ignoreMessages = true;
        applyToIgnoredUsers = true;
      };
      permissionsViewer.defaultPermissionsDropdownState = false;
      platformIndicators.badges = true;
      showHiddenChannels.hideUnreads = true;
      showHiddenThings = {
        disableDiscoveryFilters = true;
        disableDisallowedDiscoveryFilters = true;
      };
      showMeYourName = {
        displayNames = false;
        mode = "nick-user";
        inReplies = false;
        friendNicknames = "dms";
      };
      vcNarrator.voice = "English (America)+Half-LifeAnnouncementSystem espeak-ng";
    };
  };
}
