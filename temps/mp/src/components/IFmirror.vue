<template>
  <view class="U-mirror" v-if="canRender()" :hid="hid" :clone="clone" :style="STYLE">
    <slot></slot>
  </view>
</template>
